package main

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"github.com/DexterLB/potoo/go/potoo"
	"github.com/DexterLB/potoo/go/potoo/bus"
	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
	"github.com/DexterLB/potoo/go/potoo/mqtt/wrappers"
	"github.com/DexterLB/potoo/go/potoo/q"
	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/yosssi/gmq/mqtt/client"

	"github.com/valyala/fastjson"
)

type Fidget struct {
	wooBus    bus.Bus
	sliderBus bus.Bus
	clockBus  bus.Bus
	wooing    bool
}

func (f *Fidget) contract() contracts.Contract {
	return contracts.Map{
		"description": q.StringConst("Various knobs for testing purposes"),
		"methods": contracts.Map{
			"hello": contracts.Callable{
				Argument: types.Struct(
					map[string]types.Type{
						"item": types.String().M(types.MetaData{"description": q.String("item to greet")}),
					},
				),
				Retval: types.String(),
				Subcontract: contracts.Map{
					"description": q.StringConst("Performs a greeting"),
					"ui_tags":     q.StringConst("order:1"),
				},
				Handler: func(a *fastjson.Arena, arg *fastjson.Value) *fastjson.Value {
					item, err := arg.Get("item").StringBytes()
					if err != nil {
						panic(err)
					}
					time.Sleep(5 * time.Second)
					return a.NewString(fmt.Sprintf("Hello, %s", string(item)))
				},
				Async: true,
			},
			"woo": contracts.Value{
				Type: types.Float().M(types.MetaData{"min": q.Float(0), "max": q.Float(20)}),
				Bus:  f.wooBus,
			},
			"clock": contracts.Value{
				Type: types.String(),
				Bus:  f.clockBus,
			},
			"boing": contracts.Callable{
				Argument: types.Null(),
				Retval:   types.Void(),
				Handler: func(a *fastjson.Arena, arg *fastjson.Value) *fastjson.Value {
					f.wooing = !f.wooing
					return nil
				},
			},
			"slider": q.Property(
				types.Float().M(types.MetaData{"min": q.Float(0), "max": q.Float(20)}),
				f.sliderBus,
				func(a *fastjson.Arena, arg *fastjson.Value) *fastjson.Value {
					f.sliderBus.Send(arg)
					return nil
				},
				map[string]contracts.Contract{
					"ui_tags": q.StringConst("order:5,decimals:1,speed:99,exp_speed:99"),
				},
				true,
			),
		},
	}
}

func New() *Fidget {
	f := &Fidget{wooing: false}
	f.wooBus = bus.New(q.Float(0))
	f.clockBus = bus.NewWithOpts(q.String("bla"), &bus.Options{Deduplicate: true})
	f.sliderBus = bus.New(q.Float(0))
	go func() {
		var arena fastjson.Arena
		var val int
		for {
			time.Sleep(10 * time.Millisecond)
			f.clockBus.Send(q.String(time.Now().Format("2006-01-02 15:04:05")))
			if f.wooing {
				val = (val + 1) % 200
				f.wooBus.Send(arena.NewNumberFloat64(float64(val) / 10))
			}
			arena.Reset()
		}
	}()
	return f
}

func main() {
	rand.Seed(time.Now().UTC().UnixNano())
	fid := randSeq(6)
	mqttClient := wrappers.NewGmqWrapper(&wrappers.GmqOpts{
		ConnectOptions: client.ConnectOptions{
			Network:  "tcp",
			Address:  "localhost:1883",
			ClientID: []byte(fmt.Sprintf("the-go-fidget-%s", fid)),
		},
		Debug: func(msg string) {
			log.Printf(msg)
		},
	})

	opts := &potoo.ConnectionOptions{
		MqttClient:  mqttClient,
		Root:        mqtt.Topic(fmt.Sprintf("/things/fidget-%s", fid)),
		ServiceRoot: mqtt.Topic("/"),
		OnContract:  nil,
		CallTimeout: 10 * time.Second,
	}

	conn := potoo.New(opts)

	f := New()
	go func() {
		conn.UpdateContract(f.contract())
	}()

	conn.LoopOrDie()
}

var letters = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func randSeq(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}
