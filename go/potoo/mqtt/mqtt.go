package mqtt


type ConnectConfig struct {
    OnDisconnect chan<- struct{}
    OnMessage chan<- Message
    WillMessage Message
}

type Message struct {
    Topic string
    Payload []byte
    Retain bool
}

interface Client {
    // TODO: decide on syncness/asyncness of each of these.
    // or maybe the implementation should decide?
    Connect(config *ConnectConfig) error
    Publish(message *Message)
    Subscribe(filter *string) error
    Unsubscribe(filter *string) error
}
