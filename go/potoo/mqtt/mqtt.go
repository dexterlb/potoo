package mqtt

type Topic []byte

type ConnectConfig struct {
	OnDisconnect chan<- error
	OnMessage    chan<- Message
	WillMessage  Message
}

type Message struct {
	Topic   Topic
	Payload []byte
	Retain  bool
}

type Client interface {
	// TODO: decide on syncness/asyncness of each of these.
	// or maybe the implementation should decide?
	Connect(config *ConnectConfig) error
	Publish(message Message)
	Subscribe(filter Topic) // must be synchronous
	Unsubscribe(filter Topic)
	DisconnectWithWill()
	Disconnect()
}

func (c *ConnectConfig) Copy() *ConnectConfig {
	msg := c.WillMessage.Copy()
	return &ConnectConfig{
		OnDisconnect: c.OnDisconnect,
		OnMessage:    c.OnMessage,
		WillMessage:  *msg,
	}
}

func (m *Message) Copy() *Message {
	return &Message{
		Topic:   append(Topic{}, m.Topic...),
		Payload: append([]byte{}, m.Payload...),
		Retain:  m.Retain,
	}
}
