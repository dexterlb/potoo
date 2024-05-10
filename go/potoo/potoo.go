package potoo

import (
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/dexterlb/potoo/go/potoo/contracts"
	"github.com/dexterlb/potoo/go/potoo/mqtt"
	"github.com/dexterlb/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
)

type ConnectionOptions struct {
	MqttClient  mqtt.Client
	Root        mqtt.Topic
	ServiceRoot mqtt.Topic
	OnContract  func(mqtt.Topic, contracts.Contract)
	CallTimeout time.Duration
}

type Connection struct {
	opts ConnectionOptions

	arena      *fastjson.Arena
	arenaPool  *fastjson.ArenaPool
	jsonparser *fastjson.Parser
	parserPool *fastjson.ParserPool
	msgBuf     []byte

	contractTopic mqtt.Topic

	mqttDisconnect chan error
	mqttMessage    chan mqtt.Message
	updateContract chan contracts.Contract
	outgoingValues chan outgoingValue
	asyncCalls     chan asyncCallResult

	serviceCallableIndex map[string]*contracts.Callable
	unsubscribers        []func()

	connected     bool
	dead          bool
	deathMutex    sync.Mutex
	thatsAllFolks chan struct{}
}

func New(opts *ConnectionOptions) *Connection {
	c := &Connection{}

	c.opts = *opts
	c.arena = &fastjson.Arena{}
	c.arenaPool = &fastjson.ArenaPool{}
	c.jsonparser = &fastjson.Parser{}
	c.parserPool = &fastjson.ParserPool{}

	c.contractTopic = c.serviceTopic(mqtt.Topic("_contract"))

	c.mqttDisconnect = make(chan error)
	c.mqttMessage = make(chan mqtt.Message)
	c.updateContract = make(chan contracts.Contract)
	c.outgoingValues = make(chan outgoingValue)
	c.asyncCalls = make(chan asyncCallResult)

	c.serviceCallableIndex = make(map[string]*contracts.Callable)

	c.thatsAllFolks = make(chan struct{})

	return c
}

func (c *Connection) UpdateContract(contract contracts.Contract) {
	c.deathMutex.Lock()
	defer c.deathMutex.Unlock()
	if c.dead {
		return
	}
	c.updateContract <- contract
}

func (c *Connection) Connect() error {
	if c.connected {
		panic("already connected!")
	}

	c.connected = true

	connConfig := &mqtt.ConnectConfig{
		OnDisconnect: c.mqttDisconnect,
		OnMessage:    c.mqttMessage,
		WillMessage:  c.publishContractMessage(nil),
	}

	err := c.opts.MqttClient.Connect(connConfig)
	if err != nil {
		c.dead = true
		return fmt.Errorf("Could not connect to MQTT: %s", err)
	}

	return nil
}

func (c *Connection) Loop(exit <-chan struct{}) error {
	defer func() {
		c.dead = true
		go c.closeUpdateContract()
		go c.closeOutgoingValues()
		go c.closeAsyncCalls()
		c.deathMutex.Lock()
		close(c.thatsAllFolks)
		c.deathMutex.Unlock()
		c.destroyService()
	}()

	var err error
	if c.dead {
		return fmt.Errorf("Client has been unable to connect")
	}

	if !c.connected {
		err = c.Connect()
		if err != nil {
			return err
		}
	}

	defer c.opts.MqttClient.DisconnectWithWill()

	for {
		select {
		case err = <-c.mqttDisconnect:
			if err != nil {
				return fmt.Errorf("MQTT error: %s", err)
			}
			return nil
		case <-exit:
			return nil
		case msg := <-c.mqttMessage:
			c.handleMsg(msg)
		case contract := <-c.updateContract:
			err = c.handleUpdateContract(contract)
			if err != nil {
				// TODO: should we crash like this, or use c.err()?
				return fmt.Errorf("Unable to update contract: %s", err)
			}
		case ov := <-c.outgoingValues:
			err = c.handleOutgoingValue(ov)
			if err != nil {
				return fmt.Errorf("Unable to send value: %s", err)
			}
		case result := <-c.asyncCalls:
			err = c.finaliseAsyncCall(result)
			if err != nil {
				return fmt.Errorf("Error during async call: %s", err)
			}
		}
		c.arena.Reset()
	}
	return nil
}

func (c *Connection) LoopOrDie() {
	noExit := make(chan struct{})
	err := c.Loop(noExit)
	if err != nil {
		log.Fatalf("Potoo loop failed: %s", err)
	}
	log.Printf("Potoo loop finished.")
	os.Exit(0)
}

func (c *Connection) handleOutgoingValue(ov outgoingValue) error {
	err := types.TypeCheck(ov.v, ov.contract.Type)
	if err != nil {
		ov.release()
		return fmt.Errorf("Outgoing value has wrong type: %s", err)
	}

	msg := c.msg(ov.topic, ov.v, true)
	ov.release() // now safe to release ov.v

	c.publish(msg)
	return nil
}

type outgoingValue struct {
	contract *contracts.Value
	v        *fastjson.Value
	topic    mqtt.Topic
	sync     chan<- struct{}
}

func (o *outgoingValue) release() {
	if o.sync != nil {
		close(o.sync)
		o.sync = nil
	}
}

func (c *Connection) handleUpdateContract(contract contracts.Contract) error {
	c.destroyService()
	var err error
	contracts.Traverse(contract, func(subcontr contracts.Contract, subtopic mqtt.Topic) {
		if err != nil {
			return
		}

		switch s := subcontr.(type) {
		case contracts.Callable:
			topic := c.serviceTopic(mqtt.Topic("_call"), subtopic)
			c.serviceCallableIndex[string(topic)] = &s
			c.opts.MqttClient.Subscribe(topic)
		case contracts.Value:
			topic := c.serviceTopic(mqtt.Topic("_value"), subtopic)
			sub := s.Bus.Subscribe(func(v *fastjson.Value) {
				c.deathMutex.Lock()
				if c.dead {
					c.deathMutex.Unlock()
					return
				}
				sync := make(chan struct{}) // TODO: can this be done with less channels?
				c.outgoingValues <- outgoingValue{topic: topic, v: v, sync: sync, contract: &s}
				c.deathMutex.Unlock()
				<-sync
			})
			unsubscriber := func() {
				s.Bus.Unsubscribe(sub)
			}
			c.unsubscribers = append(c.unsubscribers, unsubscriber)
			defaultVal := s.Bus.Get(c.arena)
			err = c.handleOutgoingValue(outgoingValue{contract: &s, topic: topic, v: defaultVal, sync: nil})
			if err != nil {
				return
			}
		}
	})

	if err != nil {
		return fmt.Errorf("Cannot update contract: %s", err)
	}

	c.publish(c.publishContractMessage(contract))

	return nil
}

func (c *Connection) destroyService() {
	for i := range c.unsubscribers {
		c.unsubscribers[i]()
	}
	c.unsubscribers = nil
}

func (c *Connection) publishContractMessage(contract contracts.Contract) mqtt.Message {
	return c.msg(
		c.contractTopic,
		contracts.Encode(c.arena, contract),
		true,
	)
}

func (c *Connection) msg(topic mqtt.Topic, payload *fastjson.Value, retain bool, prefixes ...[]byte) mqtt.Message {
	c.msgBuf = c.msgBuf[0:0]
	for _, pref := range prefixes {
		c.msgBuf = append(c.msgBuf, pref...)
		c.msgBuf = append(c.msgBuf, ' ')
	}

	c.msgBuf = payload.MarshalTo(c.msgBuf)
	return mqtt.Message{
		Topic:   topic,
		Payload: c.msgBuf,
		Retain:  retain,
	}
}

// TODO: async calls (some way for the handler to return a channel which will be read later?)
func (c *Connection) handleCall(msg mqtt.Message, callable *contracts.Callable) error {
	if callable.Async == false {
		return c.finaliseCall(handleCallHelper(c.arena, c.jsonparser, msg, callable))
	} else {
		go func() {
			arena := c.arenaPool.Get()
			parser := c.parserPool.Get()
			result := handleCallHelper(arena, parser, msg, callable)

			c.deathMutex.Lock()
			defer c.deathMutex.Unlock()
			if c.dead {
				// the potoo service died while handling the call, there
				// is noone to return the result to
				return
			}

			c.asyncCalls <- asyncCallResult{
				callResult: result,
				arena:      arena,
				parser:     parser,
			}
		}()
	}
	return nil
}

func (c *Connection) finaliseAsyncCall(result asyncCallResult) error {
	defer c.parserPool.Put(result.parser)
	defer c.arenaPool.Put(result.arena)
	defer result.arena.Reset() // TODO: see if we really need this

	return c.finaliseCall(result.callResult)
}

func (c *Connection) finaliseCall(result callResult) error {
	if result.err != nil {
		return result.err
	}
	if result.payload == nil {
		// void call
		return nil
	}
	c.publish(c.msg(result.topic, result.payload, false, result.token))
	return nil
}

type asyncCallResult struct {
	callResult

	arena  *fastjson.Arena
	parser *fastjson.Parser
}

type callResult struct {
	err     error
	topic   mqtt.Topic
	token   []byte
	payload *fastjson.Value
}

func handleCallHelper(arena *fastjson.Arena, parser *fastjson.Parser, msg mqtt.Message, callable *contracts.Callable) callResult {
	var topic []byte
	var token []byte
	var argumentData []byte

	limitedSplit(msg.Payload, ' ', &topic, &token, &argumentData)

	argument, err := parser.ParseBytes(argumentData)
	if err != nil {
		return callResult{err: fmt.Errorf("unable to parse argument data: %s", err)}
	}

	// TODO: skip this in insane mode
	err = types.TypeCheck(argument, callable.Argument)
	if err != nil {
		return callResult{err: fmt.Errorf("argument has wrong type: %s", err)}
	}

	retval := callable.Handler(arena, argument)
	switch callable.Retval.T.(type) {
	case *types.TVoid:
		if retval != nil {
			return callResult{err: fmt.Errorf("Void-typed handler returned non-nil")}
		}
		return callResult{}
	}

	if retval == nil {
		return callResult{err: fmt.Errorf("non-void call handler returned nil!")}
	}

	// TODO: skip this in unsafe mode
	err = types.TypeCheck(retval, callable.Retval)
	if err != nil {
		return callResult{err: fmt.Errorf("Handler returned value of wrong type: %s", err)}
	}

	return callResult{
		topic:   mqtt.JoinTopics(mqtt.Topic("_reply"), mqtt.Topic(topic)),
		token:   append([]byte(nil), token...),
		payload: retval,
	}
}

func (c *Connection) handleMsg(msg mqtt.Message) {
	if callable, ok := c.serviceCallableIndex[string(msg.Topic)]; ok {
		err := c.handleCall(msg, callable)
		if err != nil {
			c.err(fmt.Errorf("error while processing call on '%s': %s", string(msg.Topic), err))
		}
		return
	}

	c.err(fmt.Errorf("don't know what to do with message on '%s'", string(msg.Topic)))
}

func (c *Connection) err(err error) {
	// gracefully handle this here
	panic(err)
}

func (c *Connection) serviceTopic(prefix mqtt.Topic, suffixes ...mqtt.Topic) mqtt.Topic {
	return mqtt.JoinTopics(
		mqtt.JoinTopics(prefix, c.opts.Root, c.opts.ServiceRoot),
		mqtt.JoinTopics(suffixes...),
	)
}

func (c *Connection) clientTopic(prefix mqtt.Topic, suffixes ...mqtt.Topic) mqtt.Topic {
	return mqtt.JoinTopics(
		mqtt.JoinTopics(prefix, c.opts.Root),
		mqtt.JoinTopics(suffixes...),
	)
}

func (c *Connection) publish(msg mqtt.Message) {
	c.opts.MqttClient.Publish(msg)
}

func limitedSplit(x []byte, sep byte, into ...(*[]byte)) {
	for i := 0; i < len(into); i++ {
		idx := -1
		for j := 0; j < len(x); j++ {
			if x[j] == ' ' {
				idx = j
				break
			}
		}
		if idx >= 0 && i < len(into)-1 {
			(*(into[i])) = x[0:idx]
			x = x[idx+1:]
		} else {
			(*(into[i])) = x
			x = x[0:0]
		}
	}
}

// these three functions are three and not one because go is stupid
// and has no generics

func (c *Connection) closeUpdateContract() {
	ch := c.updateContract

	defer close(ch)

	for {
		select {
		case _ = <-ch:
			// discard message to unblock the caller
		case _ = <-c.thatsAllFolks:
			return
		default:
			return
		}
	}
}

func (c *Connection) closeOutgoingValues() {
	ch := c.outgoingValues

	defer close(ch)

	for {
		select {
		case ov := <-ch:
			close(ov.sync)
		case _ = <-c.thatsAllFolks:
			return
		default:
			return
		}
	}
}

func (c *Connection) closeAsyncCalls() {
	ch := c.asyncCalls

	defer close(ch)

	for {
		select {
		case _ = <-ch:
			// discard message to unblock the caller
		case _ = <-c.thatsAllFolks:
			return
		default:
			return
		}
	}
}
