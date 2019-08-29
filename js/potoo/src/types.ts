/**
 * This module provides a way to describe JSON-encodeable data-types.
 */

/**
 * Any representable type
 */
export type Type = TBasic | TLiteral | TUnion | TStruct | TMap

/**
 * Any basic type
 */
type TBasic = TVoid | TNull | TBool | TInt | TFloat | TString

interface TVoid   { _t: "type-basic", name: "void",   _meta?: MetaData }
interface TNull   { _t: "type-basic", name: "null",   _meta?: MetaData }
interface TBool   { _t: "type-basic", name: "bool",   _meta?: MetaData }
interface TInt    { _t: "type-basic", name: "int",    _meta?: MetaData }
interface TFloat  { _t: "type-basic", name: "float",  _meta?: MetaData }
interface TString { _t: "type-basic", name: "string", _meta?: MetaData }

/**
 * A "literal" type - its only inhabitant is the given value.
 */
interface TLiteral {
    _t: "type-literal",
    value: any,
    _meta?: MetaData,
}

/**
 * A value is of the union type if it is of any of the `alts` types.
 */
interface TUnion {
    _t: "type-union",
    alts: Type[],
    _meta?: MetaData,
}

/**
 * The Map type represents a dictionary whose keys have the `key` type
 * and whose values have the `value` type.
 *
 * In type/javascript non-string keys should be represented as JSON.
 */
interface TMap {
    _t: "type-map",
    key: Type,
    value: Type,
    _meta?: MetaData,
}

/**
 * The List type represents a list of values that have the `value` type.
 */
interface TList {
    _t: "type-list",
    value: Type,
    _meta?: MetaData,
}

/**
 * The Struct type represents a Struct with a fixed set of named fields.
 */
interface TStruct {
    _t: "type-struct",
    fields: StructFields,
    _meta?: MetaData,
}

/**
 * The Tuple type represents a tuple with a fixed set of fields.
 * Fields are identified only by their order, as opposed to [[Struct]],
 * where they are identified by name.
 */
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

/**
 * MetaData is a key-value dictionary of additional data that may be attached
 * to a type. For example, metadata may contain min/max values for a numeric
 * type, UI hints etc.
 */
interface MetaData {
    [key: string]: number | string | boolean | null | MetaData
}

export function is_void(t: Type): t is TVoid {
    return t._t == 'type-basic' && t.name == 'void'
}

/**
 * Check if a Javascript value conforms to the given type
 */
export function typecheck(x: any, t: Type): boolean {
    console.log('please implement typecheck')
    return true
}
