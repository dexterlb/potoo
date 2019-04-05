package contracts

import (
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
)

func Decode(v *fastjson.Value) (Contract, error) {
	switch v.Type() {
	case fastjson.TypeNumber:
		n, err := v.Float64()
		noerr(err)
		return ConstantNumber(n), nil
	case fastjson.TypeTrue:
		return ConstantBool(true), nil
	case fastjson.TypeFalse:
		return ConstantBool(true), nil
	case fastjson.TypeString:
		s, err := v.StringBytes()
		noerr(err)
		return ConstantString(string(s)), nil
	case fastjson.TypeNull:
		return ConstantNull{}, nil
	case fastjson.TypeArray:
		return ConstantNull{}, fmt.Errorf("array in contract is not allowed (yet)")
	case fastjson.TypeObject:
		o, err := v.Object()
		noerr(err)
		m := make(Map)
		var key string
		o.Visit(func(k []byte, v *fastjson.Value) {
		    key = string(k)
			if err != nil {
				return
			}
			var field Contract
			field, err = Decode(v)
			m[key] = field
		})
		if err != nil {
            return ConstantNull{}, fmt.Errorf("error decoding field %s: %s", key, err)
        }
		return m, nil
	default:
	    panic("no such type!")
	}
}

func noerr(err error) {
    if err != nil {
        panic(fmt.Errorf("error should not have happened: %s", err))
    }
}
func Encode(a *fastjson.Arena, c Contract) *fastjson.Value {
	return c.encode(a)
}

func (c ConstantNumber) encode(a *fastjson.Arena) *fastjson.Value {
	return a.NewNumberFloat64(float64(c))
}

func (c ConstantBool) encode(a *fastjson.Arena) *fastjson.Value {
	if c {
		return a.NewTrue()
	} else {
		return a.NewFalse()
	}
}

func (c ConstantString) encode(a *fastjson.Arena) *fastjson.Value {
	return a.NewString(string(c))
}

func (c ConstantNull) encode(a *fastjson.Arena) *fastjson.Value {
	return a.NewNull()
}

func (m Map) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	for k := range m {
		o.Set(k, m[k].encode(a))
	}
	return o
}

func (v Value) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	o.Set("type", types.Encode(a, v.Type))
	o.Set("subcontract", v.Subcontract.encode(a))
	return o
}

func (c Callable) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	o.Set("argument", types.Encode(a, c.Argument))
	o.Set("retval", types.Encode(a, c.Retval))
	o.Set("subcontract", c.Subcontract.encode(a))
	return o
}
