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

func (b *Bus) Subscribe(handler Handler) int {
	if b == nil {
		return -1
	}

	if len(b.handlers) == 0 {
		b.opts.OnFirstSubscribed()
	}
	b.opts.OnSubscribed()

	b.handlers = append(b.handlers, handler)

	return len(b.handlers) - 1
}

func (b *Bus) Unsubscribe(i int) {
	if b == nil || i < 0 {
		return
	}

	b.handlers = append(b.handlers[:i], b.handlers[i+1:]...)
	b.opts.OnUnsubscribed()
	if len(b.handlers) == 0 {
		b.opts.OnLastUnsubscribed()
	}
}
