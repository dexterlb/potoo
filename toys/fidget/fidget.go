package main

import (
	"time"

	"github.com/DexterLB/potoo/go/potoo"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
	"github.com/DexterLB/potoo/go/potoo/mqtt/wrappers"
	"github.com/yosssi/gmq/mqtt/client"
)

func main() {
	mqttClient := wrappers.NewGmqWrapper(&wrappers.GmqOpts{
		ConnectOptions: client.ConnectOptions{
			Network:  "tcp",
			Address:  "localhost:1883",
			ClientID: []byte("the-go-fidget"),
		},
	})

	opts := &potoo.ConnectionOptions{
		MqttClient:  mqttClient,
		Root:        mqtt.Topic("/things/fidget"),
		ServiceRoot: mqtt.Topic("/"),
		OnContract:  nil,
		CallTimeout: 10 * time.Second,
	}

	conn := potoo.New(opts)

	conn.MustConnect()
}
