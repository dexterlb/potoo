package types

import (
	"fmt"

	"github.com/valyala/fastjson"
)

func MustDecode(v *fastjson.Value) Type {
	t, err := Decode(v)
	if err != nil {
		panic(err)
	}
	return t
}

func Decode(v *fastjson.Value) (Type, error) {
	nameVal := v.Get("_t")
	if nameVal == nil {
		return Type{}, fmt.Errorf("no _t field in type")
	}
	name, err := nameVal.StringBytes()
	if err != nil {
		return Type{}, fmt.Errorf("cannot decode type name: %s", err)
	}

	if descrCtor, ok := descrDic[string(name)]; ok {
		descr := descrCtor()
		descr.decode(v)
		return Type{
			Meta: decodeMetaData(v),
			T:    descr,
		}, nil
	}
	return Type{}, fmt.Errorf("no such type: %s", string(name))
}

func Encode(a *fastjson.Arena, t Type) *fastjson.Value {
    o := a.NewObject()
    o.Set("_t", a.NewString(t.T.typeName()))
    encodeMetaData(a, t.Meta, o)
    t.T.encode(a, o)
    return o
}

func (t *TVoid) decode(v *fastjson.Value) error              { return nil }
func (t *TVoid) encode(a *fastjson.Arena, v *fastjson.Value) {}

func (t *TNull) decode(v *fastjson.Value) error              { return nil }
func (t *TNull) encode(a *fastjson.Arena, v *fastjson.Value) {}

func (t *TBool) decode(v *fastjson.Value) error              { return nil }
func (t *TBool) encode(a *fastjson.Arena, v *fastjson.Value) {}

func (t *TInt) decode(v *fastjson.Value) error              { return nil }
func (t *TInt) encode(a *fastjson.Arena, v *fastjson.Value) {}

func (t *TFloat) decode(v *fastjson.Value) error              { return nil }
func (t *TFloat) encode(a *fastjson.Arena, v *fastjson.Value) {}

func (t *TString) decode(v *fastjson.Value) error              { return nil }
func (t *TString) encode(a *fastjson.Arena, v *fastjson.Value) {}

func (t *TLiteral) decode(v *fastjson.Value) error {
	t.Value = v.Get("value")
	if t.Value == nil {
		return fmt.Errorf("literal has no value")
	}
	return nil
}
func (t *TLiteral) encode(a *fastjson.Arena, v *fastjson.Value) {
	v.Set("value", t.Value)
}

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
	t.KeyType, err = Decode(keyType)
	if err != nil {
		return fmt.Errorf("cannot decode key type: %s", err)
	}
	t.ValueType, err = Decode(valueType)
	if err != nil {
		return fmt.Errorf("cannot decode value type: %s", err)
	}
	return nil
}
func (t *TMap) encode(a *fastjson.Arena, v *fastjson.Value) {
	v.Set("key", Encode(a, t.KeyType))
	v.Set("value", Encode(a, t.ValueType))
}

func (t *TList) decode(v *fastjson.Value) error {
	valueType := v.Get("value")
	if valueType == nil {
		return fmt.Errorf("list has no value type")
	}
	var err error
	t.ValueType, err = Decode(valueType)
	if err != nil {
		return fmt.Errorf("cannot decode value type: %s", err)
	}
	return nil
}
func (t *TList) encode(a *fastjson.Arena, v *fastjson.Value) {
	v.Set("value", Encode(a, t.ValueType))
}

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
		t.Alts[i], err = Decode(alts[i])
		if err != nil {
			return fmt.Errorf("cannot decode alt: %s", err)
		}
	}
	return nil
}
func (t *TUnion) encode(a *fastjson.Arena, v *fastjson.Value) {
	alts := a.NewArray()
	for i := range t.Alts {
		alts.SetArrayItem(i, Encode(a, t.Alts[i]))
	}

	v.Set("alts", alts)
}

func (t *TStruct) decode(v *fastjson.Value) error {
	fieldsVal := v.Get("fields")
	if fieldsVal == nil {
		return fmt.Errorf("struct has no fields")
	}
	fields, err := fieldsVal.Object()
	if err != nil {
		return fmt.Errorf("cannot decode fields: %s", err)
	}
	t.Fields = make(map[string]Type)
	fields.Visit(func(key []byte, t2 *fastjson.Value) {
		t.Fields[string(key)], err = Decode(t2)
		if err != nil {
			return
		}
	})
	if err != nil {
		return fmt.Errorf("cannot decode field: %s", err)
	}
	return nil
}
func (t *TStruct) encode(a *fastjson.Arena, v *fastjson.Value) {
	fields := a.NewObject()
	for key := range t.Fields {
		fields.Set(key, Encode(a, t.Fields[key]))
	}

	v.Set("fields", fields)
}

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
		t.Fields[i], err = Decode(fields[i])
		if err != nil {
			return fmt.Errorf("cannot decode field: %s", err)
		}
	}
	return nil
}
func (t *TTuple) encode(a *fastjson.Arena, v *fastjson.Value) {
	fields := a.NewArray()
	for i := range t.Fields {
		fields.SetArrayItem(i, Encode(a, t.Fields[i]))
	}

	v.Set("fields", fields)
}

var descrDic map[string](func() TypeDescr) = makeDescrDic()

func makeDescrDic() map[string](func() TypeDescr) {
	descrs := [](func() TypeDescr){
		func() TypeDescr { return &TVoid{} },
		func() TypeDescr { return &TNull{} },
		func() TypeDescr { return &TBool{} },
		func() TypeDescr { return &TInt{} },
		func() TypeDescr { return &TFloat{} },
		func() TypeDescr { return &TString{} },
		func() TypeDescr { return &TLiteral{} },
		func() TypeDescr { return &TList{} },
		func() TypeDescr { return &TMap{} },
		func() TypeDescr { return &TUnion{} },
		func() TypeDescr { return &TStruct{} },
		func() TypeDescr { return &TTuple{} },
	}
	dic := make(map[string](func() TypeDescr))
	for _, descr := range descrs {
		dic[descr().typeName()] = descr
	}
	return dic
}

func decodeMetaData(v *fastjson.Value) MetaData {
	metaVal := v.Get("meta")

	if metaVal == nil {
		return nil
	}

	o, err := metaVal.Object()
	if err != nil {
		return nil
	}

	meta := make(MetaData)
	o.Visit(func(k []byte, v *fastjson.Value) {
		meta[string(k)] = v // FIXME: must clone v here
	})
	return meta
}

func encodeMetaData(a *fastjson.Arena, meta MetaData, v *fastjson.Value) {
    if meta == nil || len(meta) == 0 {
        return
    }

    o := a.NewObject()
    for k := range meta {
         o.Set(k, meta[k])
    }
    v.Set("meta", o)
}
