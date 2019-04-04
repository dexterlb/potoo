package types

import (
	"fmt"
	"strings"

	"github.com/valyala/fastjson"
)

type Type struct {
	Meta MetaData
	T    TypeDescr
}

type TypeDescr interface {
	typeName() string
}

type TVoid struct{}
func (t *TVoid) typeName() string { return "type-void" }
func Void() Type { return Type{ T: &TVoid{} } }

type TNull struct{}
func (t *TNull) typeName() string { return "type-null" }
func Null() Type { return Type{ T: &TNull{} } }


type TBool struct{}
func (t *TBool) typeName() string { return "type-bool" }
func Bool() Type { return Type{ T: &TBool{} } }

type TInt struct{}
func (t *TInt) typeName() string { return "type-int" }
func Int() Type { return Type{ T: &TInt{} } }

type TFloat struct{}
func (t *TFloat) typeName() string { return "type-float" }
func Float() Type { return Type{ T: &TFloat{} } }

type TString struct{}
func (t *TString) typeName() string { return "type-string" }
func String() Type { return Type{ T: &TString{} } }

type TLiteral struct {
	Value *fastjson.Value
}
func (t *TLiteral) typeName() string { return "type-literal" }
func Literal(val *fastjson.Value) Type { return Type{ T: &TLiteral{Value: val} } }

type TMap struct {
	KeyType   Type
	ValueType Type
}
func (t *TMap) typeName() string { return "type-map" }
func Map(kt Type, vt Type) Type { return Type{ T: &TMap{KeyType: kt, ValueType: vt} } }

type TList struct {
	ValueType Type
}
func (t *TList) typeName() string { return "type-list" }
func List(vt Type) Type { return Type{ T: &TList{ValueType: vt} } }

type TUnion struct {
    Alts []Type
}
func (t *TUnion) typeName() string { return "type-union" }
func Union(alts ...Type) Type { return Type{ T: &TUnion{Alts: alts} } }

type TStruct struct {
    Fields map[string]Type
}
func (t *TStruct) typeName() string { return "type-struct" }
func Struct(fields map[string]Type) Type { return Type{ T: &TStruct{Fields: fields} } }

type TTuple struct {
    Fields []Type
}
func (t *TTuple) typeName() string { return "type-tuple" }
func Tuple(fields ...Type) Type { return Type{ T: &TTuple{Fields: fields} } }

type MetaData map[string]*fastjson.Value

func (t *Type) String() string {
	if t.Meta == nil || len(t.Meta) == 0 {
		return typeString(t.T)
	}
	return fmt.Sprintf("%s%s", typeString(t.T), t.Meta)
}

func (m MetaData) String() string {
	if m == nil || len(m) == 0 {
		return "<>"
	}
	items := make([]string, 0, len(m)*3)
	for k := range m {
		items = append(items, k, ": ", m[k].String())
	}

	return fmt.Sprintf("<%s>", strings.Join(items, ", "))
}

func typeString(d TypeDescr) string {
    switch typ := d.(type) {
        case *TMap:
            return fmt.Sprintf("map{%s: %s}", typ.KeyType, typ.ValueType)
        default:
            return d.typeName()
    }
}

func DecodeType(v *fastjson.Value) (Type, error) {
    return Type{}, nil
}
