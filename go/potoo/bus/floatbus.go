package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type FloatBus struct {
	sync.Mutex

	handlers []Handler
	opts     Options
	arena    fastjson.Arena
	value    float64
}

func NewFloatBus(dflt float64) *FloatBus {
	bus := &FloatBus{}
	bus.value = dflt
	return bus
}

func NewFloatBusWithOpts(dflt float64, opts *Options) *FloatBus {
	bus := NewFloatBus(dflt)
	bus.opts = *opts
	return bus
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

	if b.opts.Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *FloatBus) SendV(val float64) {
	b.Lock()
	defer b.Unlock()

	if b.opts.Deduplicate && b.value == val {
		return
	}

	b.value = val

	b.handle(val)
}

func (b *FloatBus) handle(v float64) {
	b.arena.Reset()
	jv := b.arena.NewNumberFloat64(v)
	for _, h := range b.handlers {
		h(jv)
	}
}

func (b *FloatBus) Subscribe(handler Handler) int {
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

func (b *FloatBus) Unsubscribe(i int) {
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
