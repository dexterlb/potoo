package potoo

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
	"github.com/DexterLB/potoo/go/potoo/types"
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

	return c
}

func (c *Connection) UpdateContract(contract contracts.Contract) {
	c.updateContract <- contract
}

func (c *Connection) Loop(exit <-chan struct{}) error {
	defer c.destroyService()

	connConfig := &mqtt.ConnectConfig{
		OnDisconnect: c.mqttDisconnect,
		OnMessage:    c.mqttMessage,
		WillMessage:  c.publishContractMessage(nil),
	}

	err := c.opts.MqttClient.Connect(connConfig)
	if err != nil {
		return fmt.Errorf("Could not connect to MQTT: %s", err)
	}

	for {
		select {
		case err = <-c.mqttDisconnect:
			if err != nil {
				return nil
			}
			return fmt.Errorf("MQTT error: %s", err)
		case <-exit:
			return nil
		case msg := <-c.mqttMessage:
			c.handleMsg(msg)
		case contract := <-c.updateContract:
			c.handleUpdateContract(contract)
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
	panic("not implemented")
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
			sync := make(chan struct{})
			sub := s.Bus.Subscribe(func(v *fastjson.Value) {
				c.outgoingValues <- outgoingValue{topic: topic, v: v, sync: sync}
				<-sync
			})
			unsubscriber := func() {
				s.Bus.Unsubscribe(sub)
			}
			c.unsubscribers = append(c.unsubscribers, unsubscriber)
			err = c.handleOutgoingValue(outgoingValue{contract: &s, topic: topic, v: s.Default, sync: nil})
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

type outgoingValue struct {
	contract *contracts.Value
	v        *fastjson.Value
	topic    mqtt.Topic
	sync     chan<- struct{}
}

func (c *Connection) destroyService() {
	for i := range c.unsubscribers {
		c.unsubscribers[i]()
	}
}

func (c *Connection) publishContractMessage(contract contracts.Contract) mqtt.Message {
	return c.msg(
		c.contractTopic,
		contracts.Encode(c.arena, contract),
		true,
	)
}

func (c *Connection) msg(topic mqtt.Topic, payload *fastjson.Value, retain bool) mqtt.Message {
	c.msgBuf = c.msgBuf[0:0]
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
			c.asyncCalls <- asyncCallResult{
				callResult: handleCallHelper(arena, parser, msg, callable),
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
	c.publish(c.msg(result.topic, result.payload, false))
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
	payload *fastjson.Value
}

func handleCallHelper(arena *fastjson.Arena, parser *fastjson.Parser, msg mqtt.Message, callable *contracts.Callable) callResult {
	req, err := parser.ParseBytes(msg.Payload)
	if err != nil {
		return callResult{err: fmt.Errorf("cannot parse call request JSON: %s", err)}
	}

	retTopic := req.GetStringBytes("topic")
	if retTopic == nil {
		return callResult{err: fmt.Errorf("missing 'topic' string in request json")}
	}

	token := req.Get("token")
	if token == nil {
		return callResult{err: fmt.Errorf("missing 'token' string in request json")}
	}

	argument := req.Get("argument")
	if argument == nil {
		return callResult{err: fmt.Errorf("missing 'argument' string in request json")}
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
		return callResult{err: fmt.Errorf("call failed.")}
	}

	// TODO: skip this in unsafe mode
	err = types.TypeCheck(retval, callable.Retval)
	if err != nil {
		return callResult{err: fmt.Errorf("Handler returned value of wrong type: %s", err)}
	}

	payload := arena.NewObject()
	payload.Set("token", token)
	payload.Set("result", retval)

	return callResult{topic: mqtt.JoinTopics(mqtt.Topic("_reply"), retTopic), payload: payload}
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
