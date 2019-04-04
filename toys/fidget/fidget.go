package main

import (
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
)

func main() {
	var a fastjson.Arena
    o := a.NewObject()
    o.Set("bar", a.NewNumberInt(42))
    o.Set("foo", a.NewNumberInt(45))
	err := types.TypeCheck(o, types.Map(types.String(), types.Int()))
	if err != nil {
		fmt.Printf("error: %s\n", err)
	}
}
