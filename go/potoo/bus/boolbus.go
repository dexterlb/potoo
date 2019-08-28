package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type BoolBus struct {
	sync.Mutex

	handlers []Handler
	opts     Options
	arena    fastjson.Arena
	value    bool
}

func NewBoolBus(dflt bool) *BoolBus {
	bus := &BoolBus{}
	bus.value = dflt
	return bus
}

func NewBoolBusWithOpts(dflt bool, opts *Options) *BoolBus {
	bus := NewBoolBus(dflt)
	bus.opts = *opts
	return bus
}

func (b *BoolBus) Get(arena *fastjson.Arena) *fastjson.Value {
	return newBool(arena, b.value)
}

func (b *BoolBus) Send(val *fastjson.Value) {
	v, err := val.Bool()
	if err != nil {
		panic(fmt.Errorf("trying to send a non-float value to float bus: %s", err))
	}

	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *BoolBus) SendV(val bool) {
	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == val {
		return
	}

	b.value = val

	b.handle(val)
}

func (b *BoolBus) handle(v bool) {
	b.arena.Reset()
	jv := newBool(&b.arena, v)
	for _, h := range b.handlers {
		h(jv)
	}
}

func (b *BoolBus) Subscribe(handler Handler) int {
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

func (b *BoolBus) Unsubscribe(i int) {
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

func newBool(a *fastjson.Arena, b bool) *fastjson.Value {
	if b {
		return a.NewTrue()
	} else {
		return a.NewFalse()
	}
}
