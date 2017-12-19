// Package mesh is currently a shameless copy-paste from my mpvipc package
// someday, I will make a generic interface that merges the logic of both of
// them. #nogenerics
package mesh

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"reflect"
	"sync"
)

// Connection represents a connection to a mpv IPC socket
type Connection struct {
	client  net.Conn
	address string

	lastRequest     uint
	waitingRequests map[uint]chan *commandResult

	// lastListener   uint
	// eventListeners map[uint]chan<- *Event

	lastCloseWaiter uint
	closeWaiters    map[uint]chan struct{}

	lock *sync.Mutex
}

// NewConnection returns a Connection associated with the given address
func NewConnection(address string) *Connection {
	return &Connection{
		address:         address,
		lock:            &sync.Mutex{},
		waitingRequests: make(map[uint]chan *commandResult),
		// eventListeners:  make(map[uint]chan<- *Event),
		closeWaiters: make(map[uint]chan struct{}),
	}
}

// Open connects to the socket. Returns an error if already connected.
// It also starts listening to events, so ListenForEvents() can be called
// afterwards.
func (c *Connection) Open() error {
	c.lock.Lock()
	defer c.lock.Unlock()

	if c.client != nil {
		return fmt.Errorf("already open")
	}
	client, err := net.Dial("tcp", c.address)
	if err != nil {
		return fmt.Errorf("can't connect to mpv's socket: %s", err)
	}
	c.client = client
	go c.listen()
	return nil
}

// // ListenForEvents blocks until something is received on the stop channel.
// // In the mean time, events received on the socket will be sent on the events
// // channel. They may not appear in the same order they happened in.
// func (c *Connection) ListenForEvents(events chan<- *Event, stop <-chan struct{}) {
// 	c.lock.Lock()
// 	c.lastListener++
// 	id := c.lastListener
// 	c.eventListeners[id] = events
// 	c.lock.Unlock()

// 	<-stop

// 	c.lock.Lock()
// 	delete(c.eventListeners, id)
// 	close(events)
// 	c.lock.Unlock()
// }

// // NewEventListener is a convenience wrapper around ListenForEvents(). It
// // creates and returns the event channel and the stop channel. After calling
// // NewEventListener, read events from the events channel and send an empty
// // struct to the stop channel to close it.
// func (c *Connection) NewEventListener() (chan *Event, chan struct{}) {
// 	events := make(chan *Event)
// 	stop := make(chan struct{})
// 	go c.ListenForEvents(events, stop)
// 	return events, stop
// }

// Call calls an arbitrary command and returns its result. For a list of
// possible functions, see https://mpv.io/manual/master/#commands and
// https://mpv.io/manual/master/#list-of-input-commands
func (c *Connection) Call(arguments ...interface{}) (interface{}, error) {
	c.lock.Lock()
	c.lastRequest++
	id := c.lastRequest
	resultChannel := make(chan *commandResult)
	c.waitingRequests[id] = resultChannel
	c.lock.Unlock()

	defer func() {
		c.lock.Lock()
		close(c.waitingRequests[id])
		delete(c.waitingRequests, id)
		c.lock.Unlock()
	}()

	err := c.sendCommand(id, arguments...)
	if err != nil {
		return nil, err
	}

	result := <-resultChannel
	return result.Data, nil
}

// OkCall calls the function, expecting it to return "ok"
func (c *Connection) OkCall(arguments ...interface{}) error {
	data, err := c.Call(arguments...)
	if err != nil {
		return err
	}

	if data != "ok" {
		return fmt.Errorf("got %v instead of 'ok'", data)
	}

	return nil
}

// Close closes the socket, disconnecting from mpv. It is safe to call Close()
// on an already closed connection.
func (c *Connection) Close() error {
	c.lock.Lock()
	defer c.lock.Unlock()

	if c.client != nil {
		err := c.client.Close()
		for waiterID := range c.closeWaiters {
			close(c.closeWaiters[waiterID])
		}
		c.client = nil
		return err
	}
	return nil
}

// IsClosed returns true if the connection is closed. There are several cases
// in which a connection is closed:
//
// 1. Close() has been called
//
// 2. The connection has been initialised but Open() hasn't been called yet
//
// 3. The connection terminated because of an error, mpv exiting or crashing
//
// It's ok to use IsClosed() to check if you need to reopen the connection
// before calling a command.
func (c *Connection) IsClosed() bool {
	return c.client == nil
}

// WaitUntilClosed blocks until the connection becomes closed. See IsClosed()
// for an explanation of the closed state.
func (c *Connection) WaitUntilClosed() {
	c.lock.Lock()
	if c.IsClosed() {
		c.lock.Unlock()
		return
	}

	closed := make(chan struct{})
	c.lastCloseWaiter++
	waiterID := c.lastCloseWaiter
	c.closeWaiters[waiterID] = closed

	c.lock.Unlock()

	<-closed

	c.lock.Lock()
	delete(c.closeWaiters, waiterID)
	c.lock.Unlock()
}

func (c *Connection) sendCommand(id uint, arguments ...interface{}) error {
	if c.client == nil {
		return fmt.Errorf("trying to send command on closed client")
	}
	var message []interface{}
	for _, arg := range arguments {
		message = append(message, arg)
	}
	message = append(message, id)

	data, err := json.Marshal(&message)
	if err != nil {
		return fmt.Errorf("can't encode command: %s", err)
	}
	_, err = c.client.Write(data)
	if err != nil {
		return fmt.Errorf("can't write command: %s", err)
	}
	_, err = c.client.Write([]byte("\n"))
	if err != nil {
		return fmt.Errorf("can't terminate command: %s", err)
	}
	return err
}

type commandResult struct {
	Data interface{} `json:"data"`
	ID   uint        `json:"request_id"`
}

func (c *Connection) checkResult(data []byte) {
	var resultArray []interface{}
	result := &commandResult{}

	err := json.Unmarshal(data, &resultArray)
	if err != nil {
		return // skip malformed data
	}
	if len(resultArray) != 2 {
		log.Printf("wrong length")
		return
	}
	switch id := resultArray[1].(type) {
	case uint32:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case uint:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case uint64:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case int:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case int32:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case int64:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case float32:
		result.ID = uint(id)
		result.Data = resultArray[0]
	case float64:
		result.ID = uint(id)
		result.Data = resultArray[0]
	default:
		log.Printf("wrong type: %v", reflect.TypeOf(resultArray[1]))
		return
	}

	c.lock.Lock()
	request, ok := c.waitingRequests[result.ID]
	c.lock.Unlock()
	if ok {
		request <- result
	}
}

// func (c *Connection) checkEvent(data []byte) {
// 	event := &Event{}
// 	err := json.Unmarshal(data, &event)
// 	if err != nil {
// 		return // skip malformed data
// 	}
// 	if event.Name == "" {
// 		return // not an event
// 	}
// 	c.lock.Lock()
// 	for listenerID := range c.eventListeners {
// 		listener := c.eventListeners[listenerID]
// 		go func() {
// 			listener <- event
// 		}()
// 	}
// 	c.lock.Unlock()
// }

func (c *Connection) listen() {
	scanner := bufio.NewScanner(c.client)
	for scanner.Scan() {
		data := scanner.Bytes()
		// c.checkEvent(data)
		c.checkResult(data)
	}
	_ = c.Close()
}

type Delegate struct {
	Data        interface{}
	Destination int
}

func (d *Delegate) MarshalJSON() ([]byte, error) {
	data := map[string]interface{}{
		"__type__":    interface{}("delegate"),
		"data":        d.Data,
		"destination": interface{}(d.Destination),
	}

	return json.Marshal(data)
}
