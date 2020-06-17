package bus

import (
	"sync"

	"github.com/valyala/fastjson"
)

type JsonBus struct {
	sync.Mutex

	theHandlers handlerSet
	theOpts     Options
	arena       fastjson.Arena
	value       *fastjson.Value
}

func New(dflt *fastjson.Value) *JsonBus {
	bus := &JsonBus{}
	bus.value = cloneValue(&bus.arena, dflt)
	initHandlerSet(bus.opts(), bus.handlers())
	return bus
}

func NewWithOpts(dflt *fastjson.Value, opts *Options) *JsonBus {
	bus := New(dflt)
	bus.theOpts = *opts
	initHandlerSet(bus.opts(), bus.handlers())
	return bus
}

func (b *JsonBus) handlers() *handlerSet {
	return &b.theHandlers
}

func (b *JsonBus) opts() *Options {
	return &b.theOpts
}

func (b *JsonBus) Get(arena *fastjson.Arena) *fastjson.Value {
	b.Lock()
	defer b.Unlock()

	return cloneValue(arena, b.value)
}

func (b *JsonBus) Send(val *fastjson.Value) {
	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && sameValue(val, b.value) {
		return
	}

	b.arena.Reset()
	b.value = cloneValue(&b.arena, val)

	b.handlers().broadcast(b, b.value)
}

func (b *JsonBus) Subscribe(handler Handler) int {
	return subscribeToBus(b, handler)
}

func (b *JsonBus) Unsubscribe(i int) {
	unsubscribeFromBus(b, i)
}
