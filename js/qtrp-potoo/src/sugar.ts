import * as hoshi from 'qtrp-hoshi'

import * as contracts from './contracts';

export function rconst(value: hoshi.Data): contracts.RawConstant {
    return { _t: "constant", value: value, subcontract: {} }
}
