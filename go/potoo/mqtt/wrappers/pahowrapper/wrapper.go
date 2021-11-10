package pahowrapper

import (
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/dexterlb/potoo/go/potoo/mqtt"
	paho "github.com/eclipse/paho.mqtt.golang"
	"github.com/yosssi/gmq/mqtt/client"
)

type Opts struct {
	Debug        func(string)
	ErrorHandler func(error)
}

type Wrapper struct {
	opts     *Opts
	cli      *paho.Client
	connConf *mqtt.ConnectConfig
}

func New(opts *Opts) *Wrapper {
	return &Wrapper{
		opts: opts,
	}
}

func (p *Wrapper) handleError(err error) {
	p.debug("MQTT error: %s", err)
	panic(err)
	if p.opts.ErrorHandler != nil {
		p.opts.ErrorHandler(err)
	}
	p.connConf.OnDisconnect <- err
}

func (p *Wrapper) handleMessage(topic []byte, payload []byte) {
	p.debug(" <- %s : %s", string(topic), string(payload))
	p.connConf.OnMessage <- mqtt.Message{
		Topic:   topic,
		Payload: payload,
		Retain:  false, // TODO: although not very useful, it would be nice to get this
	}
}

func (p *Wrapper) Publish(m mqtt.Message) {
	// TODO: see if there's a way to do this with less garbage
	// apparently GMQ's Publish expects its payload buffer to be untouched for some
	// time after it exits
	payload := append([]byte(nil), m.Payload...)

	p.debug(" -> %s : %s", string(m.Topic), string(m.Payload))
	var popts client.PublishOptions
	popts.QoS = p.opts.DefaultQos
	popts.Retain = m.Retain
	popts.TopicName = m.Topic
	popts.Message = payload
	err := p.cli.Publish(&popts)
	if err != nil {
		p.handleError(err)
	}
}

func (p *Wrapper) Subscribe(filter mqtt.Topic) {
	p.debug("Subscribe %s", string(filter))
	// TODO: maybe make this take a slice of filters and subscribe at once
	err := p.cli.Subscribe(&client.SubscribeOptions{
		SubReqs: []*client.SubReq{
			{
				TopicFilter: filter,
				QoS:         p.opts.DefaultQos,
				Handler:     p.handleMessage,
			},
		},
	})
	if err != nil {
		p.handleError(err)
	}
}

func (p *Wrapper) Unsubscribe(filter mqtt.Topic) {
	p.debug("unsubscribe %s", string(filter))
	// TODO: maybe make this take a slice of filters and unsubscribe at once
	err := p.cli.Unsubscribe(&client.UnsubscribeOptions{
		TopicFilters: [][]byte{filter},
	})
	if err != nil {
		p.handleError(err)
	}
}

func (p *Wrapper) Connect(config *mqtt.ConnectConfig) error {
	p.debug("connect with will %s : %s", string(config.WillMessage.Topic), string(config.WillMessage.Payload))
	p.opts.WillTopic = append([]byte(nil), config.WillMessage.Topic...)
	p.opts.WillMessage = append([]byte(nil), config.WillMessage.Payload...)
	p.opts.WillRetain = config.WillMessage.Retain
	p.opts.WillQoS = p.opts.DefaultQos

	if p.cli != nil {
		panic("trying to call Connect() on a  wrapper that has already been connected")
	}
	p.cli = client.New(&client.Options{
		ErrorHandler: p.handleError,
	})

	p.connConf = config

	return p.cli.Connect(&p.opts.ConnectOptions)
}

func (p *Wrapper) DisconnectWithWill() {
	sentWill := make(chan struct{})
	var once sync.Once
	done := func() {
		once.Do(func() { close(sentWill) })
	}

	err := p.cli.Subscribe(&client.SubscribeOptions{
		SubReqs: []*client.SubReq{
			{
				TopicFilter: p.opts.WillTopic,
				QoS:         p.opts.DefaultQos,
				Handler: func(topic []byte, payload []byte) {
					if string(payload) == string(p.opts.WillMessage) {
						done()
					}
				},
			},
		},
	})
	if err != nil {
		done() // fixme: maybe there's a better way to handle this?
	}

	var popts client.PublishOptions
	popts.QoS = p.opts.DefaultQos
	popts.Retain = p.opts.WillRetain
	popts.TopicName = p.opts.WillTopic
	popts.Message = p.opts.WillMessage
	err = p.cli.Publish(&popts)
	if err != nil {
		done()
	}

	go func() {
		time.Sleep(2 * time.Second)
		once.Do(func() {
			close(sentWill) // timeout
			fmt.Fprintf(os.Stderr, "*** FIXME *** timing out a MQTT will\n")
		})
	}()

	<-sentWill

	p.Disconnect()
}

func (p *Wrapper) Disconnect() {
	p.cli.Disconnect()
	p.debug("Disconnecting")
	close(p.connConf.OnDisconnect)
}

func (p *Wrapper) debug(s string, args ...interface{}) {
	if p.opts.Debug != nil {
		p.opts.Debug(fmt.Sprintf(s, args...))
	}
}
