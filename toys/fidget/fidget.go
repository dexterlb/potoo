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
	err := types.TypeCheck(o, types.Union(
	    types.Struct(map[string]types.Type{
            "foo": types.Int(),
            "bar": types.String(),
        }),
        types.Int(),
    ))
	if err != nil {
		fmt.Printf("error: %s\n", err)
	}
}
