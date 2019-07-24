package main

import (
	"log"
	"time"

	"github.com/DexterLB/potoo/go/potoo"
	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/DexterLB/potoo/go/potoo/mqtt/wrappers"
	"github.com/yosssi/gmq/mqtt/client"

	"github.com/valyala/fastjson"
)

type Fidget struct {
}

func (f *Fidget) contract() contracts.Contract {
	return contracts.Map{
		"description": constr("A service which provides a greeting."),
		"methods": contracts.Map{
			"hello": contracts.Callable{
				Argument: types.Struct(
					map[string]types.Type{
						"item": types.String().M(types.MetaData{"description": str("item to greet")}),
					},
				),
				Retval: types.String(),
				Subcontract: contracts.Map{
					"description": constr("Performs a greeting"),
					"ui_tags":     constr("order:1"),
				},
			},
			// "boing": {
			//     _t: "callable",
			//     argument: {_t: "type-basic", name: "null"},
			//     retval:   {_t: "type-basic", name: "void"},
			//     handler: async (_: any) => boingval.send((await boingval.get() + 1) % 20),
			//     subcontract: {
			//         "description": constr("Boing!"),
			//         "ui_tags": constr("order:3"),
			//     }
			// },
			// "boinger": {
			//     _t: "value",
			//     type: {_t: "type-basic", name: "float", _meta: {min: 0, max: 20}},
			//     bus: boingval,
			//     subcontract: {
			//         "ui_tags": constr("order:4,decimals:0"),
			//     }
			// },
			// "wooo": {
			//     _t: "value",
			//     type: {_t: "type-basic", name: "float", _meta: {min: 0, max: 20}},
			//     bus: wooval,
			//     subcontract: {
			//         "ui_tags": constr("order:4,decimals:2"),
			//     }
			// },
			// "slider": {
			//     _t: "value",
			//     type: {_t: "type-basic", name: "float", _meta: {min: 0, max: 20}},
			//     bus: sliderval,
			//     subcontract: {
			//         "set": {
			//             _t: "callable",
			//             argument: {_t: "type-basic", name: "float"},
			//             retval:   {_t: "type-basic", name: "void"},
			//             handler: async (val: any) => sliderval.send(val as number),
			//             subcontract: { },
			//         },
			//         "ui_tags": constr("order:5,decimals:1,speed:99,exp_speed:99"),
			//     }
			// },
			// "clock": {
			//     _t: "value",
			//     type: { _t: "type-basic", name: "string" },
			//     subcontract: { "description": constr("current time") },
			//     bus: timechan,
			// },
		},
	}
}

func New() *Fidget {
    return &Fidget{}
}

func main() {
	mqttClient := wrappers.NewGmqWrapper(&wrappers.GmqOpts{
		ConnectOptions: client.ConnectOptions{
			Network:  "tcp",
			Address:  "localhost:1883",
			ClientID: []byte("the-go-fidget"),
		},
		Debug: func(msg string) {
			log.Printf(msg)
		},
	})

	opts := &potoo.ConnectionOptions{
		MqttClient:  mqttClient,
		Root:        mqtt.Topic("/things/fidget"),
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

var garena fastjson.Arena // TODO: better way to handle this than a global arena
func constr(text string) contracts.Contract {
	return contracts.Constant{Value: str(text)}
}

func str(text string) *fastjson.Value {
	return garena.NewString(text)
}
