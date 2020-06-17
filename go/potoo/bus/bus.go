package bus

import (
	"sync"
	"time"

	"github.com/valyala/fastjson"
)

type RetHandler func(*fastjson.Arena, *fastjson.Value) *fastjson.Value
type Handler func(*fastjson.Value)

type Bus interface {
	Send(*fastjson.Value)
	Subscribe(Handler) int
	Unsubscribe(int)
	Get(*fastjson.Arena) *fastjson.Value
}

type Options struct {
	Deduplicate        bool
	Throttle           time.Duration
	OnFirstSubscribed  func()
	OnLastUnsubscribed func()
	OnSubscribed       func()
	OnUnsubscribed     func()
}

type handlerSet struct {
	Handlers map[int]Handler
	N        int
	opts     *Options

	// the following are used for throttling
	// this is very ugly and needs to be fixed with generics.
	throttled      bool
	lastValue      *fastjson.Value
	lastValueArena fastjson.Arena
	lastSent       *fastjson.Value
	lastSentArena  fastjson.Arena
}

func (h *handlerSet) broadcast(lock sync.Locker, v *fastjson.Value) {
	if h.throttled {
		h.lastValueArena.Reset()
		h.lastValue = cloneValue(&h.lastValueArena, v)
		return
	}

	if h.opts.Throttle != 0 {
		h.throttled = true
		go func() {
			var lv *fastjson.Value
			for {
				time.Sleep(h.opts.Throttle)

				lock.Lock()

				lv = h.lastValue
				if lv == nil {
					h.throttled = false
					lock.Unlock()
					return
				}

				if !h.opts.Deduplicate || !sameValue(h.lastSent, lv) {
					h.sendToAll(lv)
					if h.opts.Deduplicate {
						h.lastSentArena.Reset()
						h.lastSent = cloneValue(&h.lastSentArena, lv)
					}
				}
				h.lastValue = nil

				lock.Unlock()
			}
		}()

		if h.opts.Deduplicate {
			h.lastSentArena.Reset()
			h.lastSent = cloneValue(&h.lastSentArena, v)
		}
	}

	h.sendToAll(v)
}

func (h *handlerSet) sendToAll(v *fastjson.Value) {
	for _, handler := range h.Handlers {
		handler(v)
	}
}

func initHandlerSet(opts *Options, h *handlerSet) {
	h.N = 0
	h.Handlers = make(map[int]Handler)
	h.opts = opts
}

type busInternals interface {
	opts() *Options
	handlers() *handlerSet
	Lock()
	Unlock()
}

func subscribeToBus(b busInternals, handler Handler) int {
	b.Lock()
	defer b.Unlock()

	if b == nil {
		return -1
	}

	if len(b.handlers().Handlers) == 0 {
		notify(b.opts().OnFirstSubscribed)
	}
	notify(b.opts().OnSubscribed)

	b.handlers().Handlers[b.handlers().N] = handler
	b.handlers().N += 1

	return b.handlers().N - 1
}

func unsubscribeFromBus(b busInternals, i int) {
	b.Lock()
	defer b.Unlock()

	if b == nil || i < 0 {
		return
	}

	delete(b.handlers().Handlers, i)
	notify(b.opts().OnUnsubscribed)

	if len(b.handlers().Handlers) == 0 {
		notify(b.opts().OnLastUnsubscribed)
	}
}

func notify(f func()) {
	if f != nil {
		f()
	}
}

func cloneValue(arena *fastjson.Arena, val *fastjson.Value) *fastjson.Value {
	switch val.Type() {
	case fastjson.TypeNull:
		return arena.NewNull()
	case fastjson.TypeNumber:
		f, _ := val.Float64()
		return arena.NewNumberFloat64(f)
	case fastjson.TypeString:
		s, _ := val.StringBytes()
		return arena.NewStringBytes(s)
	case fastjson.TypeTrue:
		return arena.NewTrue()
	case fastjson.TypeFalse:
		return arena.NewFalse()
	case fastjson.TypeArray:
		a, _ := val.Array()
		result := arena.NewArray()
		for i := range a {
			result.SetArrayItem(i, cloneValue(arena, a[i]))
		}
		return result
	case fastjson.TypeObject:
		o, _ := val.Object()
		result := arena.NewObject()
		o.Visit(func(k []byte, v *fastjson.Value) {
			result.Set(string(k), cloneValue(arena, v))
		})
		return result
	}
	panic("not implemented")
}

func sameValue(a *fastjson.Value, b *fastjson.Value) bool {
	if a == nil || b == nil {
		return false
	}

	if a.Type() != b.Type() {
		return false
	}
	switch a.Type() {
	case fastjson.TypeNull:
		return true
	case fastjson.TypeTrue:
		return true
	case fastjson.TypeFalse:
		return true
	case fastjson.TypeNumber:
		sa, _ := a.Float64()
		sb, _ := b.Float64()
		return sa == sb
	case fastjson.TypeString:
		sa, _ := a.StringBytes()
		sb, _ := b.StringBytes()
		return string(sa) == string(sb)
	case fastjson.TypeArray:
		arra, _ := a.Array()
		arrb, _ := b.Array()
		if len(arra) != len(arrb) {
			return false
		}
		for i := range arra {
			if !sameValue(arra[i], arrb[i]) {
				return false
			}
		}
		return true
	case fastjson.TypeObject:
		oa, _ := a.Object()
		ob, _ := b.Object()

		return objectSubset(oa, ob) && objectSubset(ob, oa)
	}
	panic("not implemented")
}

func objectSubset(oa *fastjson.Object, ob *fastjson.Object) bool {
	var fail bool
	oa.Visit(func(k []byte, v *fastjson.Value) {
		if !sameValue(v, ob.Get(string(k))) {
			fail = true
		}
	})
	return !fail
}
