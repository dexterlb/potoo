package pahowrapper

import (
	"fmt"
	"time"

	"github.com/dexterlb/potoo/go/potoo/mqtt"
	paho "github.com/eclipse/paho.mqtt.golang"
)

type Opts struct {
	BrokerHostname string
	ClientID       string
	Qos            int
	DebugLogger    paho.Logger
	WarnLogger     paho.Logger
	ErrorLogger    paho.Logger
	CriticalLogger paho.Logger
	ErrorHandler   func(error)
}

type Wrapper struct {
	opts     *Opts
	client   paho.Client
	connConf *mqtt.ConnectConfig
}

func New(opts *Opts) *Wrapper {
	return &Wrapper{
		opts: opts,
	}
}

func (p *Wrapper) handleError(err error) {
	p.debug("MQTT error: %s", err)
	if p.opts.ErrorHandler != nil {
		p.opts.ErrorHandler(err)
	}
	p.connConf.OnDisconnect <- err
}

func (p *Wrapper) handleToken(token paho.Token) {
	err := unwrap(token)
	if err != nil {
		p.handleError(err)
	}
}

func (p *Wrapper) handleMessage(_client paho.Client, msg paho.Message) {
	topic := msg.Topic()
	payload := msg.Payload()
	retained := msg.Retained()

	p.debug(" <- %s : %s", topic, string(payload))
	msg := mqtt.Message{
		Topic:   []byte(topic),
		Payload: payload,
		Retain:  retained,
	}

	// we use a goroutine here just to be safe (paho doesn't like its handler to block)
	// maybe a buffered channel would be better?
	go func() {
		p.connConf.OnMessage <- msg
	}()
}

func (p *Wrapper) Publish(m mqtt.Message) {
	p.debug(" -> %s : %s", string(m.Topic), string(m.Payload))
	p.handleToken(
		p.client.Publish(string(m.Topic), byte(p.opts.Qos), m.Retain, m.Payload),
	)
}

func (p *Wrapper) Subscribe(filter mqtt.Topic) {
	p.debug("Subscribe %s", string(filter))
	p.handleToken(
		p.client.Subscribe(string(filter), byte(p.opts.Qos), nil),
	)
}

func (p *Wrapper) Unsubscribe(filter mqtt.Topic) {
	p.debug("unsubscribe %s", string(filter))
	p.handleToken(
		p.client.Unsubscribe(string(filter)),
	)
}

func (p *Wrapper) Connect(config *mqtt.ConnectConfig) error {
	paho.DEBUG = p.opts.DebugLogger
	paho.CRITICAL = p.opts.CriticalLogger
	paho.WARN = p.opts.WarnLogger
	paho.ERROR = p.opts.ErrorLogger
	p.debug("connect with will %s : %s", string(config.WillMessage.Topic), string(config.WillMessage.Payload))

	opts := paho.NewClientOptions()
	opts.AddBroker(p.opts.BrokerHostname)
	opts.SetClientID(p.opts.ClientID)

	opts.SetKeepAlive(60 * time.Second)
	opts.SetDefaultPublishHandler(p.handleMessage)
	opts.SetPingTimeout(1 * time.Second)

	p.client = paho.NewClient(opts)
	return unwrap(p.client.Connect())
}

func (p *Wrapper) DisconnectWithWill() {
	p.Publish(p.connConf.WillMessage)
	p.Disconnect()
}

func (p *Wrapper) Disconnect() {
	panic("not implemented")
	p.debug("Disconnecting")
	close(p.connConf.OnDisconnect)
}

func (p *Wrapper) debug(s string, args ...interface{}) {
	p.opts.DebugLogger.Printf(s, args...)
}

func unwrap(token paho.Token) error {
	if !token.Wait() {
		return fmt.Errorf("mqtt token Wait() returned false")
	}
	return token.Error()
}
