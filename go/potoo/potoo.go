package potoo

import (
	"fmt"
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
}

func New(opts *ConnectionOptions) *Connection {
	return &Connection{
		opts: *opts,
	}
}

func (c *Connection) Connect() error {
    fmt.Printf("conn %v\n", c)
    return nil
}

func (c *Connection) MustConnect() {
	err := c.Connect()
	if err != nil {
		panic(err)
	}
}
