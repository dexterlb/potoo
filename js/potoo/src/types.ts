export type Type = TBasic | TLiteral | TUnion | TStruct | TMap

type TBasic = TVoid | TNull | TBool | TInt | TFloat | TString

interface TVoid   { _t: "type-basic", name: "void",   _meta?: MetaData }
interface TNull   { _t: "type-basic", name: "null",   _meta?: MetaData }
interface TBool   { _t: "type-basic", name: "bool",   _meta?: MetaData }
interface TInt    { _t: "type-basic", name: "int",    _meta?: MetaData }
interface TFloat  { _t: "type-basic", name: "float",  _meta?: MetaData }
interface TString { _t: "type-basic", name: "string", _meta?: MetaData }

interface TLiteral {
    _t: "type-literal",
    value: any,
    _meta?: MetaData,
}

interface TUnion {
    _t: "type-union",
    alts: Type[],
    _meta?: MetaData,
}

interface TMap {
    _t: "type-map",
    key: Type,
    value: Type,
    _meta?: MetaData,
}

interface TList {
    _t: "type-list",
    value: Type,
    _meta?: MetaData,
}

interface TStruct {
    _t: "type-struct",
    fields: StructFields,
    _meta?: MetaData,
}

interface TTuple {
    _t: "type-tuple",
    fields: TupleFields,
    _meta?: MetaData,
}

interface TupleFields {
    [idx: number]: Type;
}

interface StructFields {
    [key: string]: Type;
}

interface MetaData {
    [key: string]: number | string | boolean | null | MetaData
}

export function is_void(t: Type): boolean {
    return t._t == 'type-basic' && t.name == 'void'
}

export function typecheck(x: any, t: Type): boolean {
    console.log('please implement typecheck')
    return true
}
