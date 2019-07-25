package wrappers

import (
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/mqtt"
	"github.com/yosssi/gmq/mqtt/client"
)

type GmqOpts struct {
	client.ConnectOptions
	DefaultQos   byte
	Debug        func(string)
	ErrorHandler func(error)
}

type GmqWrapper struct {
	opts     *GmqOpts
	cli      *client.Client
	connConf *mqtt.ConnectConfig
}

func NewGmqWrapper(opts *GmqOpts) *GmqWrapper {
	return &GmqWrapper{
		opts: opts,
	}
}

func (g *GmqWrapper) handleError(err error) {
	if g.opts.Debug != nil {
		g.opts.Debug(fmt.Sprintf("[gmq] MQTT error: %s", err))
	}
	g.connConf.OnDisconnect <- err
	if g.opts.ErrorHandler != nil {
		g.opts.ErrorHandler(err)
	}
}

func (g *GmqWrapper) handleMessage(topic []byte, payload []byte) {
	if g.opts.Debug != nil {
		g.opts.Debug(fmt.Sprintf("[gmq] <- %s : %s", string(topic), string(payload)))
	}
	g.connConf.OnMessage <- mqtt.Message{
		Topic:   topic,
		Payload: payload,
		Retain:  false, // TODO: although not very useful, it would be nice to get this
	}
}

func (g *GmqWrapper) Publish(m mqtt.Message) {
    // TODO: see if there's a way to do this with less garbage
    // apparently GMQ's Publish expects its payload buffer to be untouched for some
    // time after it exits
    payload := append([]byte(nil), m.Payload...) 

	if g.opts.Debug != nil {
		g.opts.Debug(fmt.Sprintf("[gmq] -> %s : %s", string(m.Topic), string(m.Payload)))
	}
	var popts client.PublishOptions
	popts.QoS = g.opts.DefaultQos
	popts.Retain = m.Retain
	popts.TopicName = m.Topic
	popts.Message = payload
	err := g.cli.Publish(&popts)
	if err != nil {
		g.handleError(err)
	}
}

func (g *GmqWrapper) Subscribe(filter mqtt.Topic) {
	if g.opts.Debug != nil {
		g.opts.Debug(fmt.Sprintf("[gmq] subscribe %s", string(filter)))
	}
	// TODO: maybe make this take a slice of filters and subscribe at once
	err := g.cli.Subscribe(&client.SubscribeOptions{
		SubReqs: []*client.SubReq{
			&client.SubReq{
				TopicFilter: filter,
				QoS:         g.opts.DefaultQos,
				Handler:     g.handleMessage,
			},
		},
	})
	if err != nil {
		g.handleError(err)
	}
}

func (g *GmqWrapper) Unsubscribe(filter mqtt.Topic) {
	if g.opts.Debug != nil {
		g.opts.Debug(fmt.Sprintf("[gmq] unsubscribe %s", string(filter)))
	}
	// TODO: maybe make this take a slice of filters and unsubscribe at once
	err := g.cli.Unsubscribe(&client.UnsubscribeOptions{
		TopicFilters: [][]byte{filter},
	})
	if err != nil {
		g.handleError(err)
	}
}

func (g *GmqWrapper) Connect(config *mqtt.ConnectConfig) error {
	if g.opts.Debug != nil {
		g.opts.Debug(fmt.Sprintf("[gmq] connect with will %s : %s", string(config.WillMessage.Topic), string(config.WillMessage.Payload)))
	}
	g.opts.WillTopic = config.WillMessage.Topic
	g.opts.WillMessage = config.WillMessage.Payload
	g.opts.WillRetain = config.WillMessage.Retain
	g.opts.WillQoS = g.opts.DefaultQos

	if g.cli != nil {
		panic("trying to call Connect() on a Gmq wrapper that has already been connected")
	}
	g.cli = client.New(&client.Options{
		ErrorHandler: g.handleError,
	})

	g.connConf = config

	return g.cli.Connect(&g.opts.ConnectOptions)
}
