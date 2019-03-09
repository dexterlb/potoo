import {Type}    from './types';
import {Channel} from './channel';
import {Topic}   from './mqtt'

export type RawContract     = Constant
                            | RawValue
                            | RawCallable
                            | RawMapContract
export type Contract        = Constant
                            | Value
                            | Callable
                            | MapContract

type Constant = null | boolean | number | string

interface RawMapContract {
    [key: string]: RawContract
}

interface MapContract {
    [key: string]: Contract
}

interface ValueDescr {
    _t: "value",
    type: Type,
}

interface CallableDescr {
    _t: "callable",
    argument: Type,
    retval: Type,
}

export function isValue(x: any) : x is ValueDescr {
    return (x != null) && (typeof x == 'object') && (x._t == 'value')
}

export function isCallable(x: any) : x is CallableDescr {
    return (x != null) && (typeof x == 'object') && (x._t == 'callable')
}

export interface Value extends ValueDescr {
    subcontract: MapContract,
    channel: Channel<any>
}

export interface Callable extends CallableDescr {
    subcontract: MapContract,
    handler: (argument: any) => any
}

export interface RawValue extends ValueDescr {
    subcontract: RawMapContract,
}

export interface RawCallable extends CallableDescr {
    subcontract: RawMapContract,
}

export function traverse(c: Contract, f: (c: Contract, topic: Topic) => void) {
    traverse_helper(c, f, [])
}

function traverse_helper(c: Contract, f: (c: Contract, topic: Topic) => void, path: Array<string>) {
    f(c, make_topic(path))
    if (isValue(c) || isCallable(c)) {
        traverse(c.subcontract, f)
        return
    }
    if (typeof c == 'object') {
        for (let key in c) {
            path.push(key)
            traverse(c[key], f)
            path.pop()
        }
    }
}

export function encode(c: Contract): RawContract {
    if (isValue(c)) {
        return { _t: c._t, type: c.type, subcontract: encode_map(c.subcontract) }
    }
    if (isCallable(c)) {
        return { _t: c._t, argument: c.argument, retval: c.retval, subcontract: encode_map(c.subcontract) }
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

export function make_topic(items: Array<string>): Topic {
    return items.join('/')
}
