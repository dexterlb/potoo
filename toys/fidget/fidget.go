package main

import (
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/mqtt"
	"github.com/DexterLB/potoo/go/potoo/mqtt/wrappers"
	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
	"github.com/yosssi/gmq/mqtt/client"
)

func main() {
	var a fastjson.Arena
	o := a.NewObject()
	o.Set("bar", a.NewString("baz"))
	o.Set("foo", a.NewNumberInt(45))
	t := types.MustDecode(fastjson.MustParse(`
        { "_t": "type-union", "alts": [
            { "_t": "type-float", "meta": { "min": 0, "max": 1 } },
            { "_t": "type-struct", "meta": { "foo": "bar" }, "fields":
                { "foo": { "_t": "type-int" },
                "bar": { "_t": "type-string" }
                }
            }
        ] }
    `))
	err := types.TypeCheck(o, t)
	if err != nil {
		fmt.Printf("error: %s\n", err)
		return
	}

	fmt.Printf("json: %s\n", types.Encode(&a, t).String())
	fmt.Printf("contract: %v\n", contracts.Constant{Value: a.NewNumberInt(42)})
	var wr mqtt.Client
	wr = wrappers.NewGmqWrapper(&wrappers.GmqOpts{
		ConnectOptions: client.ConnectOptions{
			Network: "websocket",
			Address: "ws://localhost:8330",
		},
	})
	err = wr.Connect(&mqtt.ConnectConfig{})
	if err != nil {
		fmt.Printf("error: %s\n", err)
		return
	}
}
