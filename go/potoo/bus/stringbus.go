package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type StringBus struct {
	sync.Mutex

	handlers []Handler
	opts     Options
	arena    fastjson.Arena
	value    string
}

func NewStringBus(dflt string) *StringBus {
	bus := &StringBus{}
	bus.value = dflt
	return bus
}

func NewStringBusWithOpts(dflt string, opts *Options) *StringBus {
	bus := NewStringBus(dflt)
	bus.opts = *opts
	return bus
}

func (b *StringBus) Get(arena *fastjson.Arena) *fastjson.Value {
	return arena.NewString(b.value)
}

func (b *StringBus) Send(val *fastjson.Value) {
	vb, err := val.StringBytes()
	if err != nil {
		panic(fmt.Errorf("trying to send a non-string value to string bus: %s", err))
	}
	v := string(vb)

	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *StringBus) SendV(val string) {
	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == val {
		return
	}

	b.value = val

	b.handle(val)
}

func (b *StringBus) GetV() string {
	return b.value
}

func (b *StringBus) handle(v string) {
	b.arena.Reset()
	jv := b.arena.NewString(v)
	for _, h := range b.handlers {
		h(jv)
	}
}

func (b *StringBus) Subscribe(handler Handler) int {
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

func (b *StringBus) Unsubscribe(i int) {
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
