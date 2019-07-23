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
}

func New(opts *ConnectionOptions) *Connection {
	c := &Connection{}

	c.opts = *opts
    c.arena = &fastjson.Arena{}

    c.contractTopic = c.serviceTopic(mqtt.Topic("_contract"))

	return c
}

func (c *Connection) Loop(exit <-chan struct{}) error {
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
