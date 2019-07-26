package bus

import (
	"sync"

	"github.com/valyala/fastjson"
)

type RetHandler func(*fastjson.Arena, *fastjson.Value) *fastjson.Value
type Handler func(*fastjson.Value)

type Bus interface {
	Send(*fastjson.Value)
	Subscribe(Handler) int
	Unsubscribe(int)
	Get(*fastjson.Arena) *fastjson.Value
}

type JsonBus struct {
	sync.Mutex

	handlers []Handler
	opts     BusOptions
	arena    fastjson.Arena
	first    chan struct{}
	value    *fastjson.Value
}

type BusOptions struct {
	Deduplicate        bool
	OnFirstSubscribed  func()
	OnLastUnsubscribed func()
	OnSubscribed       func()
	OnUnsubscribed     func()
}

func New() *JsonBus {
	return &JsonBus{
		first: make(chan struct{}),
	}
}

func NewWithOpts(opts *BusOptions) *JsonBus {
	bus := New()
	bus.opts = *opts
	return bus
}

func (b *JsonBus) Get(arena *fastjson.Arena) *fastjson.Value {
	<-b.first
	b.Lock()
	defer b.Unlock()

	return cloneValue(arena, b.value)
}

func (b *JsonBus) Send(val *fastjson.Value) {
	defer b.signalFirst()

	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && sameValue(val, b.value) {
		return
	}

	b.arena.Reset()
	b.value = cloneValue(&b.arena, val)

	for _, h := range b.handlers {
		h(b.value)
	}
}

func (b *JsonBus) signalFirst() {
    if b.first != nil {
        close(b.first)
        b.first = nil
    }
}

func (b *JsonBus) Subscribe(handler Handler) int {
	b.Lock()
	defer b.Unlock()

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

func (b *JsonBus) Unsubscribe(i int) {
	b.Lock()
	defer b.Unlock()

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

func cloneValue(arena *fastjson.Arena, val *fastjson.Value) *fastjson.Value {
    switch(val.Type()) {
        case fastjson.TypeNull:
            return arena.NewNull()
        case fastjson.TypeNumber:
            f, _ := val.Float64()
            return arena.NewNumberFloat64(f)
    }
    panic("not implemented")
}

func sameValue(a *fastjson.Value, b *fastjson.Value) bool {
	panic("not implemented")
}
