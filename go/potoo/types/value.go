package types

import (
	"fmt"

	"github.com/valyala/fastjson"
)

func TypeCheck(v *fastjson.Value, t Type) error {
    var err error
    switch typ := t.T.(type) {
	case TVoid:
		return fmt.Errorf("trying to typecheck a value against Void, which is uninhabitable")
	case TNull:
		if v.Type() == fastjson.TypeNull {
			return nil
		}
	case TBool:
		if v.Type() == fastjson.TypeTrue || v.Type() == fastjson.TypeFalse {
			return nil
		}
	case TInt, TFloat:
		if v.Type() == fastjson.TypeNumber {
			return nil
		}
	case TString:
		if v.Type() == fastjson.TypeString {
			return nil
		}
    case TLiteral:
        panic("literals not yet implemented")
    case TMap:
        var o *fastjson.Object
        o, err = v.Object()
        if err == nil {
            o.Visit(func(key []byte, v2 *fastjson.Value) {
                err = TypeCheck(v2, typ.ValueType)
                if err != nil {
                    return
                }
            })
        }
        if err == nil {
            return nil
        }
	}
	if err == nil {
	    err = fmt.Errorf("type mismatch")
	}
    return fmt.Errorf("value %s doesn't match type %s: %s", v, t, err)
}
