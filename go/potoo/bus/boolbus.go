package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type BoolBus struct {
	sync.Mutex

	theHandlers handlerSet
	theOpts     Options
	arena       fastjson.Arena
	value       bool
}

func NewBoolBus(dflt bool) *BoolBus {
	bus := &BoolBus{}
	bus.value = dflt
	initHandlerSet(bus.handlers())
	return bus
}

func NewBoolBusWithOpts(dflt bool, opts *Options) *BoolBus {
	bus := NewBoolBus(dflt)
	bus.theOpts = *opts
	initHandlerSet(bus.handlers())
	return bus
}

func (b *BoolBus) handlers() *handlerSet {
	return &b.theHandlers
}

func (b *BoolBus) opts() *Options {
	return &b.theOpts
}

func (b *BoolBus) Get(arena *fastjson.Arena) *fastjson.Value {
	return newBool(arena, b.value)
}

func (b *BoolBus) Send(val *fastjson.Value) {
	v, err := val.Bool()
	if err != nil {
		panic(fmt.Errorf("trying to send a non-bool value to bool bus: %s", err))
	}

	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *BoolBus) SendV(val bool) {
	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == val {
		return
	}

	b.value = val

	b.handle(val)
}

func (b *BoolBus) GetV() bool {
	return b.value
}

func (b *BoolBus) handle(v bool) {
	b.arena.Reset()
	jv := newBool(&b.arena, v)
	b.handlers().broadcast(jv)
}

func (b *BoolBus) Subscribe(handler Handler) int {
	return subscribeToBus(b, handler)
}

func (b *BoolBus) Unsubscribe(i int) {
	unsubscribeFromBus(b, i)
}

func newBool(a *fastjson.Arena, b bool) *fastjson.Value {
	if b {
		return a.NewTrue()
	} else {
		return a.NewFalse()
	}
}
