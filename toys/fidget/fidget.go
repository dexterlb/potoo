package main

import (
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
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


	fmt.Printf(types.Encode(&a, t).String())
}
