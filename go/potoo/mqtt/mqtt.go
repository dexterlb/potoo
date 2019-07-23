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
	Publish(message *Message)
	Subscribe(filter Topic) // must be synchronous
	Unsubscribe(filter Topic)
}
