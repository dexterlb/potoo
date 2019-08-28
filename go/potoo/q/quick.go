package q

import (
	"encoding/json"
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/bus"
	"github.com/DexterLB/potoo/go/potoo/contracts"
	"github.com/DexterLB/potoo/go/potoo/types"

	"github.com/valyala/fastjson"
)

func Property(t types.Type, b bus.Bus, handler bus.RetHandler, children map[string]contracts.Contract, async bool) contracts.Contract {
	subcontract := contracts.Map{
		"set": contracts.Callable{
			Handler:  handler,
			Async:    async,
			Argument: t,
			Retval:   types.Void(),
		},
	}
	if children != nil {
		for key := range children {
			subcontract[key] = children[key]
		}
	}
	return contracts.Value{
		Bus:         b,
		Subcontract: subcontract,
		Type:        t,
	}
}

func String(s string) *fastjson.Value {
	var a fastjson.Arena
	return a.NewString(s)
}

func StringConst(s string) contracts.Contract {
	return contracts.Constant{Value: String(s)}
}

func Float(x float64) *fastjson.Value {
	var a fastjson.Arena
	return a.NewNumberFloat64(x)
}

func FloatConst(x float64) contracts.Contract {
	return contracts.Constant{Value: Float(x)}
}

func Json(x interface{}) *fastjson.Value {
	data, err := json.Marshal(x)
	if err != nil {
		panic(fmt.Errorf("Cannot marshal JSON: %s", err))
	}

	var parser fastjson.Parser
	v, err := parser.ParseBytes(data)
	if err != nil {
		panic(fmt.Errorf("Cannot re-parse JSON: %s", err))
	}

	return v
}

func JsonConst(x interface{}) contracts.Contract {
	return contracts.Constant{Value: Json(x)}
}
