package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type IntBus struct {
	sync.Mutex

	handlers []Handler
	opts     Options
	arena    fastjson.Arena
	value    int
}

func NewIntBus(dflt int) *IntBus {
	bus := &IntBus{}
	bus.value = dflt
	return bus
}

func NewIntBusWithOpts(dflt int, opts *Options) *IntBus {
	bus := NewIntBus(dflt)
	bus.opts = *opts
	return bus
}

func (b *IntBus) Get(arena *fastjson.Arena) *fastjson.Value {
	return arena.NewNumberFloat64(float64(b.value))
}

func (b *IntBus) Send(val *fastjson.Value) {
	fv, err := val.Float64()
	if err != nil {
		panic(fmt.Errorf("trying to send a non-int value to int bus: %s", err))
	}

	v := int(fv)

	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *IntBus) SendV(val int) {
	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == val {
		return
	}

	b.value = val

	b.handle(val)
}

func (b *IntBus) GetV() int {
	return b.value
}

func (b *IntBus) handle(v int) {
	b.arena.Reset()
	jv := b.arena.NewNumberFloat64(float64(v))
	for _, h := range b.handlers {
		h(jv)
	}
}

func (b *IntBus) Subscribe(handler Handler) int {
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

func (b *IntBus) Unsubscribe(i int) {
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
