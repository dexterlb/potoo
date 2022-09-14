package bus

import (
	"fmt"
	"sync"

	"github.com/mxmCherry/movavg"
	"github.com/valyala/fastjson"
)

type FloatBus struct {
	sync.Mutex

	theHandlers handlerSet
	theOpts     Options
	arena       fastjson.Arena
	value       float64
	averaging   *movavg.SMA
}

func NewFloatBus(dflt float64) *FloatBus {
	bus := &FloatBus{}
	bus.value = dflt
	initHandlerSet(bus.opts(), bus.handlers())
	return bus
}

func NewFloatBusWithOpts(dflt float64, opts *Options) *FloatBus {
	if opts.AveragingWindow > 1 {
		return NewAveragingFloatBusWithOpts(dflt, opts, opts.AveragingWindow)
	}

	bus := NewFloatBus(dflt)
	bus.theOpts = *opts
	initHandlerSet(bus.opts(), bus.handlers())
	return bus
}

// same as calling NewFloatBusWithOpts with a set AveragingWindow
func NewAveragingFloatBusWithOpts(dflt float64, opts *Options, window int) *FloatBus {
	bus := NewFloatBusWithOpts(dflt, opts)
	bus.averaging = movavg.NewSMA(window)
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

	b.SendV(v)
}

func (b *FloatBus) SendV(val float64) {
	b.Lock()
	defer b.Unlock()

	if b.averaging != nil {
		b.averaging.Add(val)
		val = b.averaging.Avg()
	}

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
	b.handlers().broadcast(b, jv)
}

func (b *FloatBus) Subscribe(handler Handler) int {
	return subscribeToBus(b, handler)
}

func (b *FloatBus) Unsubscribe(i int) {
	unsubscribeFromBus(b, i)
}
