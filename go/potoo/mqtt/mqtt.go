package mqtt

type ConnectConfig struct {
	OnDisconnect chan<- struct{}
	OnMessage    chan<- Message
	WillMessage  Message
}

type Message struct {
	Topic   []byte
	Payload []byte
	Retain  bool
}

type Client interface {
	// TODO: decide on syncness/asyncness of each of these.
	// or maybe the implementation should decide?
	Connect(config *ConnectConfig) error
	Publish(message *Message)
	Subscribe(filter []byte)   // must be synchronous
	Unsubscribe(filter []byte)
}
