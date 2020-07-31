import * as hoshi     from 'qtrp-hoshi'
import {Bus}          from './bus'
import {Topic}        from './mqtt'
import {contractType} from './meta'

export type RawContract     = RawConstant
                            | RawValue
                            | RawCallable
                            | RawMapContract
                            | null

export type Contract        = Constant
                            | Value
                            | Callable
                            | MapContract
                            | null

export interface RawMapContract {
    [key: string]: RawContract
}

export interface MapContract {
    [key: string]: Contract
}

export interface ValueDescr {
    _t: "value",
    type: hoshi.Schema,
}

export interface CallableDescr {
    _t: "callable",
    argument: hoshi.Schema,
    retval: hoshi.Schema,
}

export interface ConstantDescr {
    _t: "constant",
    value: hoshi.Data,
}

export function isValue(x: any) : x is ValueDescr {
    return (x != null) && (typeof x == 'object') && (x._t == 'value')
}

export function isCallable(x: any) : x is CallableDescr {
    return (x != null) && (typeof x == 'object') && (x._t == 'callable')
}

export function isConstant(x: any) : x is ConstantDescr {
    return (x != null) && (typeof x == 'object') && (x._t == 'constant')
}

export interface Value extends ValueDescr {
    subcontract: MapContract,
    bus: Bus<any>
}

export interface Callable extends CallableDescr {
    subcontract: MapContract,
    handler: Handler
}

export interface Constant extends ConstantDescr {
    subcontract: MapContract
}

export interface RawValue extends ValueDescr {
    subcontract: RawMapContract,
}

export interface RawCallable extends CallableDescr {
    subcontract: RawMapContract,
}

export interface RawConstant extends ConstantDescr {
    subcontract: RawMapContract
}

export interface Call {
    topic: string,
    token: string,
    argument: any,
}

export interface CallResponse {
    token: string,
    result: any,
}

export interface Handler {
    (argument: any): Promise<any>
}

export function traverse(c: Contract, f: (c: Contract, topic: Topic) => void) {
    traverse_helper(c, f, [], true)
}

function traverse_helper(c: Contract, f: (c: Contract, topic: Topic) => void, path: Array<string>, call_f: boolean) {
    if (call_f) {
        f(c, make_topic(path))
    }
    if (isValue(c) || isCallable(c) || isConstant(c)) {
        traverse_helper(c.subcontract, f, path, false)
        return
    }
    if (typeof c == 'object') {
        for (let key in c) {
            path.push(key)
            traverse_helper(c[key], f, path, true)
            path.pop()
        }
    }
}

export interface DecodeOptions {
    valueBus: (v: RawValue) => Bus<any>,
    callHandler: (c: RawCallable) => Handler,
}

export function decode(c: RawContract, o: DecodeOptions): Contract {
    if (isValue(c)) {
        return { _t: c._t, type: c.type, subcontract: decode_map(c.subcontract, o),
                 bus: o.valueBus(c) }
    }
    if (isCallable(c)) {
        return { _t: c._t, argument: c.argument, retval: c.retval, subcontract: decode_map(c.subcontract, o),
                 handler: o.callHandler(c) }
    }
    if (isConstant(c)) {
        return { _t: c._t, value: c.value, subcontract: decode_map(c.subcontract, o) }
    }
    if (c != null && typeof c == 'object') {
        return decode_map(c, o)
    }
    return c
}

function decode_map(c: RawMapContract, o: DecodeOptions): MapContract {
    let result: { [key: string]: Contract } = {}
    for (let key in c) {
        result[key] = decode(c[key], o)
    }
    return result
}

export function encode(c: Contract): RawContract {
    if (isValue(c)) {
        return { _t: c._t, type: c.type, subcontract: encode_map(c.subcontract) }
    }
    if (isCallable(c)) {
        return { _t: c._t, argument: c.argument, retval: c.retval, subcontract: encode_map(c.subcontract) }
    }
    if (isConstant(c)) {
        return { _t: c._t, value: c.value, subcontract: encode_map(c.subcontract) }
    }
    if (c != null && typeof c == 'object') {
        return encode_map(c)
    }
    return c
}

function encode_map(c: MapContract): RawMapContract {
    let result: { [key: string]: RawContract } = {}
    for (let key in c) {
        result[key] = encode(c[key])
    }
    return result
}

function child_map(c: MapContract, key: string): MapContract {
    if (key == '') {
        return c
    }
    if (key in c) {
        let o = c[key]
        if (typeof o == 'object' && o != null) {
            if (isValue(o) || isCallable(o) || isConstant(o)) {
                return o.subcontract
            }
            return o
        }
    }
    let o = {}
    c[key] = o
    return o
}

function to_map(c: Contract): MapContract {
    if (typeof c == 'object' && c != null) {
        if (isValue(c) || isCallable(c) || isConstant(c)) {
            return c.subcontract
        }
        return c
    }
    return {}   // non-map root contracts not supported
}

export function attach_at(into: MapContract, path: Topic, contract: Contract): MapContract {
    let items = path.split('/')
    let last  = items.pop()
    if (last == undefined) {
        return to_map(contract)
    }

    let iter = into
    items.forEach(key => {
        iter = child_map(iter, key)
    })

    iter[last] = contract

    return into
}

export function make_topic(items: Array<string>): Topic {
    return items.join('/')
}

export function check(contract: RawContract): hoshi.Ok | hoshi.TypeErr {
    return hoshi.typecheck(contract as hoshi.Data, contractType)
}
