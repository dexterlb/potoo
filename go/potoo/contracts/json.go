package contracts

import (
	"fmt"

	"github.com/DexterLB/potoo/go/potoo/types"
	"github.com/valyala/fastjson"
)

func Decode(v *fastjson.Value) (Contract, error) {
    if v == nil {
        return nil, fmt.Errorf("item does not exist")
    }

	switch v.Type() {
	case fastjson.TypeNull:
		return nil, nil
	case fastjson.TypeObject:
		tv := v.Get("_t")
		if tv != nil {
            t, err := tv.StringBytes()
            if err != nil {
                return nil, fmt.Errorf("_t is not a string: %s", err)
            }
			switch string(t) {
			case "value":
				return decodeValue(v)
			case "callable":
				return decodeCallable(v)
			case "constant":
				return decodeConstant(v)
			}
		}
		return decodeMap(v)
	default:
		panic("no such type!")
	}
}

func decodeValue(v *fastjson.Value) (Contract, error) {
    typ, err := types.DecodeSchema(v.Get("type"))
    if err != nil {
        return nil, fmt.Errorf("invalid type on value: %s", err)
    }
    subcontract, err := Decode(v.Get("subcontract"))
    if err != nil {
        return nil, fmt.Errorf("invalid subcontract on value: %s", err)
    }

    return Value {
        Type: typ,
        Subcontract: subcontract,
    }, nil
}

func decodeConstant(v *fastjson.Value) (Contract, error) {
    val := v.Get("value")
    if val == nil {
        return nil, fmt.Errorf("no value on constant")
    }

    subcontract, err := Decode(v.Get("subcontract"))
    if err != nil {
        return nil, fmt.Errorf("invalid subcontract on constant: %s", err)
    }

    return Constant {
        Value: val,
        Subcontract: subcontract,
    }, nil
}

func decodeCallable(v *fastjson.Value) (Contract, error) {
    argument, err := types.DecodeSchema(v.Get("argument"))
    if err != nil {
        return nil, fmt.Errorf("invalid argument on callable: %s", err)
    }
    retval, err := types.DecodeSchema(v.Get("retval"))
    if err != nil {
        return nil, fmt.Errorf("invalid retval on callable: %s", err)
    }
    subcontract, err := Decode(v.Get("subcontract"))
    if err != nil {
        return nil, fmt.Errorf("invalid subcontract on callable: %s", err)
    }

    return Callable {
        Argument: argument,
        Retval: retval,
        Subcontract: subcontract,
    }, nil
}

func decodeMap(v *fastjson.Value) (Map, error) {
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
		return nil, fmt.Errorf("error decoding field %s: %s", key, err)
	}
	return m, nil
}

func noerr(err error) {
	if err != nil {
		panic(fmt.Errorf("error should not have happened: %s", err))
	}
}
func Encode(a *fastjson.Arena, c Contract) *fastjson.Value {
    if c == nil {
        return a.NewNull()
    }
	return c.encode(a)
}

func (m Map) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	for k := range m {
		o.Set(k, Encode(a, m[k]))
	}
	return o
}

func (c Constant) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	o.Set("_t", a.NewString(c.contractNode()))
	o.Set("value", c.Value)
	o.Set("subcontract", Encode(a, c.Subcontract))
	return o
}

func (v Value) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	o.Set("_t", a.NewString(v.contractNode()))
	o.Set("type", types.EncodeSchema(a, v.Type))
	o.Set("subcontract", Encode(a, v.Subcontract))
	return o
}

func (c Callable) encode(a *fastjson.Arena) *fastjson.Value {
	o := a.NewObject()
	o.Set("_t", a.NewString(c.contractNode()))
	o.Set("argument", types.EncodeSchema(a, c.Argument))
	o.Set("retval", types.EncodeSchema(a, c.Retval))
	o.Set("subcontract", Encode(a, c.Subcontract))
	return o
}
