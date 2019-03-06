export type Type = TBasic | TLiteral | TUnion

type TBasic = TVoid | TNull | TBool | TInt | TFloat | TString

interface TVoid   { _t: "type-basic", name: "void",  _meta?: object }
interface TNull   { _t: "type-basic", name: "null",  _meta?: object }
interface TBool   { _t: "type-basic", name: "bool",  _meta?: object }
interface TInt    { _t: "type-basic", name: "int",   _meta?: object }
interface TFloat  { _t: "type-basic", name: "float", _meta?: object }
interface TString { _t: "type-basic", name: "float", _meta?: object }

interface TLiteral {
    _t: "type-literal",
    value: any,
    _meta: object,
}

interface TUnion {
    _t: "type-union",
    alts: Type[],
    _meta: object,
}

interface TMap {
    _t: "type-map",
    key: Type,
    value: Type,
    _meta: object,
}

interface TList {
    _t: "type-list",
    value: Type,
    _meta: object,
}

interface TStruct {
    _t: "type-struct",
    fields: StructFields,
    _meta: object,
}

interface StructFields {
    [key: string]: Type;
}
