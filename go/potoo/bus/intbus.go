package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type IntBus struct {
	sync.Mutex

	theHandlers handlerSet
	theOpts     Options
	arena       fastjson.Arena
	value       int
}

func NewIntBus(dflt int) *IntBus {
	bus := &IntBus{}
	bus.value = dflt
	initHandlerSet(bus.opts(), bus.handlers())
	return bus
}

func NewIntBusWithOpts(dflt int, opts *Options) *IntBus {
	bus := NewIntBus(dflt)
	bus.theOpts = *opts
	initHandlerSet(bus.opts(), bus.handlers())
	return bus
}

func (b *IntBus) handlers() *handlerSet {
	return &b.theHandlers
}

func (b *IntBus) opts() *Options {
	return &b.theOpts
}

func (b *IntBus) Get(arena *fastjson.Arena) *fastjson.Value {
	return arena.NewNumberInt(b.value)
}

func (b *IntBus) Send(val *fastjson.Value) {
	v, err := val.Int()
	if err != nil {
		panic(fmt.Errorf("trying to send a non-int value to int bus: %s", err))
	}

	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *IntBus) SendV(val int) {
	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == val {
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
	jv := b.arena.NewNumberInt(v)
	b.handlers().broadcast(b, jv)
}

func (b *IntBus) Subscribe(handler Handler) int {
	return subscribeToBus(b, handler)
}

func (b *IntBus) Unsubscribe(i int) {
	unsubscribeFromBus(b, i)
}
