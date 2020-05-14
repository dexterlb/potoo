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
	typeKey() string
	typeName() string
	typeString() string
	decode(v *fastjson.Value) error
	encode(a *fastjson.Arena, v *fastjson.Value)
}

type TVoid struct{}

func (t *TVoid) typeKey() string    { return "type-basic" }
func (t *TVoid) typeName() string   { return "void" }
func (t *TVoid) typeString() string { return "void" }
func Void() Type                    { return Type{T: &TVoid{}} }

type TNull struct{}

func (t *TNull) typeKey() string    { return "type-basic" }
func (t *TNull) typeName() string   { return "null" }
func (t *TNull) typeString() string { return "null" }
func Null() Type                    { return Type{T: &TNull{}} }

type TBool struct{}

func (t *TBool) typeKey() string    { return "type-basic" }
func (t *TBool) typeName() string   { return "bool" }
func (t *TBool) typeString() string { return "bool" }
func Bool() Type                    { return Type{T: &TBool{}} }

type TInt struct{}

func (t *TInt) typeKey() string    { return "type-basic" }
func (t *TInt) typeName() string   { return "int" }
func (t *TInt) typeString() string { return "int" }
func Int() Type                    { return Type{T: &TInt{}} }

type TFloat struct{}

func (t *TFloat) typeKey() string    { return "type-basic" }
func (t *TFloat) typeName() string   { return "float" }
func (t *TFloat) typeString() string { return "float" }
func Float() Type                    { return Type{T: &TFloat{}} }

type TString struct{}

func (t *TString) typeKey() string    { return "type-basic" }
func (t *TString) typeName() string   { return "string" }
func (t *TString) typeString() string { return "string" }
func String() Type                    { return Type{T: &TString{}} }

type TLiteral struct {
	Value *fastjson.Value
}

func (t *TLiteral) typeKey() string    { return "type-literal" }
func (t *TLiteral) typeName() string   { return "" }
func (t *TLiteral) typeString() string { return fmt.Sprintf("literal[%s]", t.Value) }
func Literal(val *fastjson.Value) Type { return Type{T: &TLiteral{Value: val}} }

type TMap struct {
	KeyType   Type
	ValueType Type
}

func (t *TMap) typeKey() string  { return "type-map" }
func (t *TMap) typeName() string { return "" }
func (t *TMap) typeString() string {
	return fmt.Sprintf("map[%s: %s]", t.KeyType, t.ValueType)
}
func Map(kt Type, vt Type) Type { return Type{T: &TMap{KeyType: kt, ValueType: vt}} }

type TList struct {
	ValueType Type
}

func (t *TList) typeKey() string  { return "type-list" }
func (t *TList) typeName() string { return "list" }
func (t *TList) typeString() string {
	return fmt.Sprintf("list[%s]", t.ValueType)
}
func List(vt Type) Type { return Type{T: &TList{ValueType: vt}} }

type TUnion struct {
	Alts []Type
}

func (t *TUnion) typeKey() string  { return "type-union" }
func (t *TUnion) typeName() string { return "" }
func (t *TUnion) typeString() string {
	alts := make([]string, len(t.Alts))
	for i := range t.Alts {
		alts[i] = t.Alts[i].String()
	}
	return strings.Join(alts, " | ")
}
func Union(alts ...Type) Type { return Type{T: &TUnion{Alts: alts}} }

type TStruct struct {
	Fields map[string]Type
}

func (t *TStruct) typeKey() string  { return "type-struct" }
func (t *TStruct) typeName() string { return "" }
func (t *TStruct) typeString() string {
	fields := make([]string, len(t.Fields))
	i := 0
	for k := range t.Fields {
		fields[i] = fmt.Sprintf("%s: %s", k, t.Fields[k])
		i++
	}
	return fmt.Sprintf("struct[%s]", strings.Join(fields, ", "))
}
func Struct(fields map[string]Type) Type { return Type{T: &TStruct{Fields: fields}} }

type TTuple struct {
	Fields []Type
}

func (t *TTuple) typeKey() string  { return "type-tuple" }
func (t *TTuple) typeName() string { return "" }
func (t *TTuple) typeString() string {
	fields := make([]string, len(t.Fields))
	for i := range t.Fields {
		fields[i] = t.Fields[i].String()
	}
	return fmt.Sprintf("tuple[%s]", strings.Join(fields, ", "))
}
func Tuple(fields ...Type) Type { return Type{T: &TTuple{Fields: fields}} }

func (t Type) String() string {
	if t.Meta == nil || len(t.Meta) == 0 {
		return t.T.typeString()
	}
	return fmt.Sprintf("%s%s", t.T.typeString(), t.Meta)
}
