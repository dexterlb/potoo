package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type FloatBus struct {
	sync.Mutex

	theHandlers handlerSet
	theOpts     Options
	arena       fastjson.Arena
	value       float64
}

func NewFloatBus(dflt float64) *FloatBus {
	bus := &FloatBus{}
	bus.value = dflt
	initHandlerSet(bus.handlers())
	return bus
}

func NewFloatBusWithOpts(dflt float64, opts *Options) *FloatBus {
	bus := NewFloatBus(dflt)
	bus.theOpts = *opts
	initHandlerSet(bus.handlers())
	return bus
}

func (b *FloatBus) handlers() *handlerSet {
	return &b.theHandlers
}

func (b *FloatBus) opts() *Options {
	return &b.theOpts
}

func (b *FloatBus) Get(arena *fastjson.Arena) *fastjson.Value {
	return arena.NewNumberFloat64(b.value)
}

func (b *FloatBus) Send(val *fastjson.Value) {
	v, err := val.Float64()
	if err != nil {
		panic(fmt.Errorf("trying to send a non-float value to float bus: %s", err))
	}

	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *FloatBus) SendV(val float64) {
	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == val {
		return
	}

	b.value = val

	b.handle(val)
}

func (b *FloatBus) GetV() float64 {
	return b.value
}

func (b *FloatBus) handle(v float64) {
	b.arena.Reset()
	jv := b.arena.NewNumberFloat64(v)
	b.handlers().broadcast(jv)
}

func (b *FloatBus) Subscribe(handler Handler) int {
	return subscribeToBus(b, handler)
}

func (b *FloatBus) Unsubscribe(i int) {
	unsubscribeFromBus(b, i)
}
