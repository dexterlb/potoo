package potoo

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
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

	mqttDisconnect chan error
	mqttMessage    chan mqtt.Message
}

func New(opts *ConnectionOptions) *Connection {
	return &Connection{
		opts: *opts,
	}
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
	panic("not implemented")
}

func (c *Connection) handleMsg(msg mqtt.Message) {

}
