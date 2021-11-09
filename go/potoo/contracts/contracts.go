package contracts

import (
	"github.com/dexterlb/potoo/go/potoo/bus"
	"github.com/dexterlb/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
)

type Contract interface {
	contractNode() string
	encode(a *fastjson.Arena) *fastjson.Value
}

type Map map[string]Contract

func (m Map) contractNode() string { return "_map" }

type Constant struct {
	Value       *fastjson.Value
	Subcontract Contract
}

func (v Constant) contractNode() string { return "constant" }

type Value struct {
	Type        types.Type
	Subcontract Contract
	Bus         bus.Bus
}

func (v Value) contractNode() string { return "value" }

type Callable struct {
	Argument    types.Type
	Retval      types.Type
	Subcontract Contract
	Handler     bus.RetHandler
	Async       bool
}

func (c Callable) contractNode() string { return "callable" }
