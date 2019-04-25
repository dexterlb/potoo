package wrappers

import (
    "github.com/yosssi/gmq/mqtt/client"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
)

type GmqOpts struct {
	client.ConnectOptions
	DefaultQos   byte
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
	g.connConf.OnDisconnect <- struct{}{}
	if g.opts.ErrorHandler != nil {
		g.opts.ErrorHandler(err)
	}
}

func (g *GmqWrapper) handleMessage(topic []byte, payload []byte) {
    g.connConf.OnMessage <- mqtt.Message{
        Topic: topic,
        Payload: payload,
        Retain: false,  // TODO: although not very useful, it would be nice to get this
    }
}

func (g *GmqWrapper) Publish(m *mqtt.Message) {
    var popts client.PublishOptions
    popts.QoS = g.opts.DefaultQos
    popts.Retain = m.Retain
    popts.TopicName = m.Topic
    popts.Message = m.Payload
    err := g.cli.Publish(&popts)
    if err != nil {
        g.handleError(err)
    }
}

func (g *GmqWrapper) Subscribe(filter []byte) {
    // TODO: maybe make this take a slice of filters and subscribe at once
    err := g.cli.Subscribe(&client.SubscribeOptions{
        SubReqs: []*client.SubReq{
            &client.SubReq{
                TopicFilter: filter,
                QoS: g.opts.DefaultQos,
                Handler: g.handleMessage,
            },
        },
    })
    if err != nil {
        g.handleError(err)
    }
}

func (g *GmqWrapper) Unsubscribe(filter []byte) {
    // TODO: maybe make this take a slice of filters and unsubscribe at once
    err := g.cli.Unsubscribe(&client.UnsubscribeOptions{
        TopicFilters: [][]byte{filter},
    })
    if err != nil {
        g.handleError(err)
    }
}

func (g *GmqWrapper) Connect(config *mqtt.ConnectConfig) error {
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
