package bus

import (
	"github.com/valyala/fastjson"
)

type RetHandler func(*fastjson.Arena, *fastjson.Value) *fastjson.Value
type Handler func(*fastjson.Value)

type Bus struct {
	handlers []Handler
	opts     BusOptions
}

type BusOptions struct {
	OnFirstSubscribed  func()
	OnLastUnsubscribed func()
	OnSubscribed       func()
	OnUnsubscribed     func()
}

func New() *Bus {
    return &Bus{}
}

func NewWithOpts(opts *BusOptions) *Bus {
    return &Bus{opts: *opts}
}

func (b *Bus) Send(val *fastjson.Value) {
    for _, h := range b.handlers {
        h(val)
    }
}

func (b *Bus) Subscribe(handler Handler) int {
	if b == nil {
		return -1
	}

	if len(b.handlers) == 0 {
		notify(b.opts.OnFirstSubscribed)
	}
	notify(b.opts.OnSubscribed)

	b.handlers = append(b.handlers, handler)

	return len(b.handlers) - 1
}

func (b *Bus) Unsubscribe(i int) {
	if b == nil || i < 0 {
		return
	}

	b.handlers = append(b.handlers[:i], b.handlers[i+1:]...)
	notify(b.opts.OnUnsubscribed)
	if len(b.handlers) == 0 {
		notify(b.opts.OnLastUnsubscribed)
	}
}

func notify(f func()) {
    if f != nil {
        f()
    }
}
