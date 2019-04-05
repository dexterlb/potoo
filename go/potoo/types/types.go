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
	decode(v *fastjson.Value) error
	encode(a *fastjson.Arena, v *fastjson.Value) error
}

type TVoid struct{}
func (t *TVoid) typeName() string { return "type-void" }
func Void() Type { return Type{ T: &TVoid{} } }
func (t *TVoid) decode(v *fastjson.Value) error { return nil }
func (t *TVoid) encode(a *fastjson.Arena, v *fastjson.Value) error { return nil }

type TNull struct{}
func (t *TNull) typeName() string { return "type-null" }
func Null() Type { return Type{ T: &TNull{} } }
func (t *TNull) decode(v *fastjson.Value) error { return nil }
func (t *TNull) encode(a *fastjson.Arena, v *fastjson.Value) error { return nil }


type TBool struct{}
func (t *TBool) typeName() string { return "type-bool" }
func Bool() Type { return Type{ T: &TBool{} } }
func (t *TBool) decode(v *fastjson.Value) error { return nil }
func (t *TBool) encode(a *fastjson.Arena, v *fastjson.Value) error { return nil }

type TInt struct{}
func (t *TInt) typeName() string { return "type-int" }
func Int() Type { return Type{ T: &TInt{} } }
func (t *TInt) decode(v *fastjson.Value) error { return nil }
func (t *TInt) encode(a *fastjson.Arena, v *fastjson.Value) error { return nil }

type TFloat struct{}
func (t *TFloat) typeName() string { return "type-float" }
func Float() Type { return Type{ T: &TFloat{} } }
func (t *TFloat) decode(v *fastjson.Value) error { return nil }
func (t *TFloat) encode(a *fastjson.Arena, v *fastjson.Value) error { return nil }

type TString struct{}
func (t *TString) typeName() string { return "type-string" }
func String() Type { return Type{ T: &TString{} } }
func (t *TString) decode(v *fastjson.Value) error { return nil }
func (t *TString) encode(a *fastjson.Arena, v *fastjson.Value) error { return nil }

type TLiteral struct {
	Value *fastjson.Value
}
func (t *TLiteral) typeName() string { return "type-literal" }
func Literal(val *fastjson.Value) Type { return Type{ T: &TLiteral{Value: val} } }
func (t *TLiteral) decode(v *fastjson.Value) error {
    t.Value = v.Get("value")
    if t.Value == nil {
        return fmt.Errorf("literal has no value")
    }
    return nil
}
func (t *TLiteral) encode(a *fastjson.Arena, v *fastjson.Value) error {
    v.Set("value", t.Value)
    return nil
}

type TMap struct {
	KeyType   Type
	ValueType Type
}
func (t *TMap) typeName() string { return "type-map" }
func Map(kt Type, vt Type) Type { return Type{ T: &TMap{KeyType: kt, ValueType: vt} } }
func (t *TMap) decode(v *fastjson.Value) error {
    keyType := v.Get("key")
    if keyType == nil {
        return fmt.Errorf("map has no key type")
    }
    valueType := v.Get("value")
    if valueType == nil {
        return fmt.Errorf("map has no value type")
    }
    var err error
    t.KeyType, err = DecodeType(keyType)
    if err != nil {
        return fmt.Errorf("cannot decode key type: %s", err)
    }
    t.ValueType, err = DecodeType(valueType)
    if err != nil {
        return fmt.Errorf("cannot decode value type: %s", err)
    }
    return nil
}
func (t *TMap) encode(a *fastjson.Arena, v *fastjson.Value) error {
    keyType, err := EncodeType(a, t.KeyType)
    if err != nil {
        return fmt.Errorf("cannot encode key type: %s", err)
    }
    valueType, err := EncodeType(a, t.ValueType)
    if err != nil {
        return fmt.Errorf("cannot encode value type: %s", err)
    }

    v.Set("key", keyType)
    v.Set("value", valueType)
    return nil
}

type TList struct {
	ValueType Type
}
func (t *TList) typeName() string { return "type-list" }
func List(vt Type) Type { return Type{ T: &TList{ValueType: vt} } }
func (t *TList) decode(v *fastjson.Value) error {
    valueType := v.Get("value")
    if valueType == nil {
        return fmt.Errorf("list has no value type")
    }
    var err error
    t.ValueType, err = DecodeType(valueType)
    if err != nil {
        return fmt.Errorf("cannot decode value type: %s", err)
    }
    return nil
}
func (t *TList) encode(a *fastjson.Arena, v *fastjson.Value) error {
    valueType, err := EncodeType(a, t.ValueType)
    if err != nil {
        return fmt.Errorf("cannot encode value type: %s", err)
    }

    v.Set("value", valueType)
    return nil
}

type TUnion struct {
    Alts []Type
}
func (t *TUnion) typeName() string { return "type-union" }
func Union(alts ...Type) Type { return Type{ T: &TUnion{Alts: alts} } }
func (t *TUnion) decode(v *fastjson.Value) error {
    altsVal := v.Get("alts")
    if altsVal == nil {
        return fmt.Errorf("union has no alts")
    }
    alts, err := altsVal.Array()
    if err != nil {
        return fmt.Errorf("cannot decode alts: %s", err)
    }
    t.Alts = make([]Type, len(alts))
    for i := range alts {
        t.Alts[i], err = DecodeType(alts[i])
        if err != nil {
            return fmt.Errorf("cannot decode alt: %s", err)
        }
    }
    return nil
}
func (t *TUnion) encode(a *fastjson.Arena, v *fastjson.Value) error {
    alts := a.NewArray()
    for i := range t.Alts {
        alt, err := EncodeType(a, t.Alts[i])
        if err != nil {
            return fmt.Errorf("cannot encode alt: %s", err)
        }
        alts.SetArrayItem(i, alt)
    }

    v.Set("alts", alts)
    return nil
}

type TStruct struct {
    Fields map[string]Type
}
func (t *TStruct) typeName() string { return "type-struct" }
func Struct(fields map[string]Type) Type { return Type{ T: &TStruct{Fields: fields} } }
func (t *TStruct) decode(v *fastjson.Value) error {
    fieldsVal := v.Get("alts")
    if fieldsVal == nil {
        return fmt.Errorf("struct has no fields")
    }
    fields, err := fieldsVal.Object()
    if err != nil {
        return fmt.Errorf("cannot decode fields: %s", err)
    }
    t.Fields = make(map[string]Type)
    fields.Visit(func(key []byte, t2 *fastjson.Value) {
        t.Fields[string(key)], err = DecodeType(t2)
        if err != nil {
            return
        }
    })
    if err != nil {
        return fmt.Errorf("cannot decode field: %s", err)
    }
    return nil
}
func (t *TStruct) encode(a *fastjson.Arena, v *fastjson.Value) error {
    fields := a.NewObject()
    for key := range t.Fields {
        field, err := EncodeType(a, t.Fields[key])
        if err != nil {
            return fmt.Errorf("cannot encode field: %s", err)
        }
        fields.Set(key, field)
    }

    v.Set("fields", fields)
    return nil
}

type TTuple struct {
    Fields []Type
}
func (t *TTuple) typeName() string { return "type-tuple" }
func Tuple(fields ...Type) Type { return Type{ T: &TTuple{Fields: fields} } }
func (t *TTuple) decode(v *fastjson.Value) error {
    fieldsVal := v.Get("fields")
    if fieldsVal == nil {
        return fmt.Errorf("tuple has no fields")
    }
    fields, err := fieldsVal.Array()
    if err != nil {
        return fmt.Errorf("cannot decode fields: %s", err)
    }
    t.Fields = make([]Type, len(fields))
    for i := range fields {
        t.Fields[i], err = DecodeType(fields[i])
        if err != nil {
            return fmt.Errorf("cannot decode field: %s", err)
        }
    }
    return nil
}
func (t *TTuple) encode(a *fastjson.Arena, v *fastjson.Value) error {
    fields := a.NewArray()
    for i := range t.Fields {
        field, err := EncodeType(a, t.Fields[i])
        if err != nil {
            return fmt.Errorf("cannot encode field: %s", err)
        }
        fields.SetArrayItem(i, field)
    }

    v.Set("fields", fields)
    return nil
}

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

func EncodeType(a *fastjson.Arena, t Type) (*fastjson.Value, error) {
    return nil, nil
}
