import {Type}    from './types';
import {Channel} from './channel';

export type Contract        = Constant
                            | Value
                            | Callable
                            | MapContract
export type ServiceContract = Constant
                            | ServiceValue
                            | ServiceCallable
                            | MapServiceContract

type Constant = null | boolean | number | string

interface MapContract {
    [key: string]: Contract
}

interface MapServiceContract {
    [key: string]: ServiceContract
}

interface Value {
    _t: "value",
    type: Type,
    subcontract: Contract,
}

interface Callable {
    _t: "callable",
    argument: Type,
    retval: Type,
    subcontract: Contract,
}

interface ServiceValue extends Value {
    channel: Channel<any>
}

interface ServiceCallable extends Callable {
    handler: (argument: any) => any
}
