package potoo

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
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

	arena  *fastjson.Arena
	msgBuf []byte

	contractTopic mqtt.Topic

	mqttDisconnect chan error
	mqttMessage    chan mqtt.Message
	updateContract chan contracts.Contract
	outgoingValues chan outgoingValue

	serviceCallableIndex map[string]*contracts.Callable
	unsubscribers        []func()
}

func New(opts *ConnectionOptions) *Connection {
	c := &Connection{}

	c.opts = *opts
	c.arena = &fastjson.Arena{}

	c.contractTopic = c.serviceTopic(mqtt.Topic("_contract"))

	c.mqttDisconnect = make(chan error)
	c.mqttMessage = make(chan mqtt.Message)
	c.updateContract = make(chan contracts.Contract)
	c.outgoingValues = make(chan outgoingValue)

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
		}
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
		case *contracts.Callable:
			topic := c.serviceTopic(mqtt.Topic("_call"), subtopic)
			c.serviceCallableIndex[string(topic)] = s
			c.opts.MqttClient.Subscribe(topic)
		case *contracts.Value:
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
			err = c.handleOutgoingValue(outgoingValue{contract: s, topic: topic, v: s.Default, sync: nil})
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

func (c *Connection) handleMsg(msg mqtt.Message) {
	panic("not implemented")
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
