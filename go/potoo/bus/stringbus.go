package bus

import (
	"fmt"
	"sync"

	"github.com/valyala/fastjson"
)

type StringBus struct {
	sync.Mutex

	theHandlers handlerSet
	theOpts     Options
	arena       fastjson.Arena
	value       string
}

func NewStringBus(dflt string) *StringBus {
	bus := &StringBus{}
	bus.value = dflt
	initHandlerSet(bus.handlers())
	return bus
}

func NewStringBusWithOpts(dflt string, opts *Options) *StringBus {
	bus := NewStringBus(dflt)
	bus.theOpts = *opts
	initHandlerSet(bus.handlers())
	return bus
}

func (b *StringBus) handlers() *handlerSet {
	return &b.theHandlers
}

func (b *StringBus) opts() *Options {
	return &b.theOpts
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

	if b.opts().Deduplicate && b.value == v {
		return
	}
	b.value = v

	b.handle(v)
}

func (b *StringBus) SendV(val string) {
	b.Lock()
	defer b.Unlock()

	if b.opts().Deduplicate && b.value == val {
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
	b.handlers().broadcast(jv)
}

func (b *StringBus) Subscribe(handler Handler) int {
	return subscribeToBus(b, handler)
}

func (b *StringBus) Unsubscribe(i int) {
	unsubscribeFromBus(b, i)
}
