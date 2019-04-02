package types

type Type struct {
    Meta MetaData
    T    TypeDescr
}

type TypeDescr interface {
    TypeName() string
}

type TVoid struct{}
func (t TVoid) TypeName() string { return "void" }

type TNull struct{}
func (t TNull) TypeName() string { return "null" }

type TBool struct{}
func (t TBool) TypeName() string { return "bool" }

type TInt struct{}
func (t TInt) TypeName() string { return "int" }

type TFloat struct{}
func (t TFloat) TypeName() string { return "float" }

type TString struct{}
func (t TString) TypeName() string { return "string" }

type TLiteral struct {
    Value Fuck
}
func (t TLiteral) TypeName() string { return "literal" }

type TMap struct {
    Key Type
    Value Type
}
func (t TMap) TypeName() string { return "map" }

type MetaData map[string]Fuck

func Foo() string {
    return "42\n"
}
