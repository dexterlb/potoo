package pahowrapper

import (
	"github.com/dexterlb/potoo/go/potoo/mqtt"
	paho "github.com/eclipse/paho.mqtt.golang"
)

type Opts struct {
	Protocol       string
	BrokerHostname string
	ClientID       string
	DebugLogger    paho.Logger
	WarnLogger     paho.Logger
	ErrorLogger    paho.Logger
	CriticalLogger paho.Logger
	ErrorHandler   func(error)
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
	p.debug(" -> %s : %s", string(m.Topic), string(m.Payload))
	panic("not implemented")
	// if err != nil {
	// 	p.handleError(err)
	// }
}

func (p *Wrapper) Subscribe(filter mqtt.Topic) {
	p.debug("Subscribe %s", string(filter))
	panic("not implemented")
}

func (p *Wrapper) Unsubscribe(filter mqtt.Topic) {
	p.debug("unsubscribe %s", string(filter))
	panic("not implemented")
}

func (p *Wrapper) Connect(config *mqtt.ConnectConfig) error {
	paho.DEBUG = p.opts.DebugLogger
	paho.CRITICAL = p.opts.CriticalLogger
	paho.WARN = p.opts.WarnLogger
	paho.ERROR = p.opts.ErrorLogger
	p.debug("connect with will %s : %s", string(config.WillMessage.Topic), string(config.WillMessage.Payload))
	panic("not implemented")
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
