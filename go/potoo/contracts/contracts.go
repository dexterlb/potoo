package contracts

import (
	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
)

type Contract interface {
	contractNode() string
	encode(a *fastjson.Arena) *fastjson.Value
}

type ConstantNumber float64

func (c ConstantNumber) contractNode() string { return "constant-number" }

type ConstantBool bool

func (c ConstantBool) contractNode() string { return "constant-bool" }

type ConstantString string

func (c ConstantString) contractNode() string { return "constant-string" }

type ConstantNull struct{}

func (c ConstantNull) contractNode() string { return "constant-null" }

type Map map[string]Contract

func (m Map) contractNode() string { return "map" }

type Value struct {
	Type        types.Type
	Subcontract Contract
}

func (v Value) contractNode() string { return "value" }

type Callable struct {
	Argument    types.Type
	Retval      types.Type
	Subcontract Contract
}

func (c Callable) contractNode() string { return "callable" }
