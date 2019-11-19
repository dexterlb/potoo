package types

import (
	"fmt"
	"strings"

	"github.com/valyala/fastjson"
)

func TypeCheck(v *fastjson.Value, t Type) error {
	var err error
	switch typ := t.T.(type) {
	case *TVoid:
		return fmt.Errorf("trying to typecheck a value against Void, which is uninhabitable")
	case *TNull:
		if v.Type() == fastjson.TypeNull {
			return nil
		}
	case *TBool:
		if v.Type() == fastjson.TypeTrue || v.Type() == fastjson.TypeFalse {
			return nil
		}
	case *TInt, *TFloat:
		if v.Type() == fastjson.TypeNumber {
			return nil
		}
	case *TString:
		if v.Type() == fastjson.TypeString {
			return nil
		}
	case *TLiteral:
		if sameValue(v, typ.Value) {
			return nil
		} else {
			return fmt.Errorf(
				"literal value '%s' doesn't match '%s'",
				v.String(),
				typ.Value.String(),
			)
		}
	case *TMap:
		var o *fastjson.Object
		o, err = v.Object()
		if err == nil {
			o.Visit(func(key []byte, v2 *fastjson.Value) {
				if err != nil {
					return
				}
				err = TypeCheck(v2, typ.ValueType)
			})
		}
		if err == nil {
			return nil
		}
	case *TTuple:
		var a []*fastjson.Value
		a, err = v.Array()
		if err == nil {
			if len(a) != len(typ.Fields) {
				err = fmt.Errorf("number of fields differs")
			}
			for i := range a {
				err = TypeCheck(a[i], typ.Fields[i])
				if err != nil {
					break
				}
			}
		}
		if err == nil {
			return nil
		}
	case *TStruct:
		var o *fastjson.Object
		o, err = v.Object()
		if err == nil {
			if o.Len() != len(typ.Fields) {
				err = fmt.Errorf("number of fields differs")
			}
			o.Visit(func(key []byte, v2 *fastjson.Value) {
				if err != nil {
					return
				}
				if t2, ok := typ.Fields[string(key)]; ok {
					err = TypeCheck(v2, t2)
				} else {
					err = fmt.Errorf("field %s is not supposed to be here", string(key))
				}
			})
		}
		if err == nil {
			return nil
		}
	case *TList:
		var a []*fastjson.Value
		a, err = v.Array()
		if err == nil {
			for i := range a {
				err = TypeCheck(a[i], typ.ValueType)
				if err != nil {
					break
				}
			}
		}
		if err == nil {
			return nil
		}
	case *TUnion:
		var errs []string
		for i := range typ.Alts {
			err = TypeCheck(v, typ.Alts[i])
			if err == nil {
				return nil
			}
			errs = append(errs, fmt.Sprintf(" - %s\n", err))
		}
		if err == nil {
			err = fmt.Errorf("empty union type is uninhabitable")
		} else {
			err = fmt.Errorf("neither type in union matched:\n%s", strings.Join(errs, ""))
		}
	}
	if err == nil {
		err = fmt.Errorf("type mismatch")
	}
	return fmt.Errorf("value %s doesn't match %s: %s", v, t, err)
}

func sameValue(a *fastjson.Value, b *fastjson.Value) bool {
	// FIXME: this is very wrong and slow and must be fixed
	var adat []byte
	var bdat []byte
	adat = a.MarshalTo(adat)
	bdat = b.MarshalTo(bdat)
	return string(adat) == string(bdat)
}
