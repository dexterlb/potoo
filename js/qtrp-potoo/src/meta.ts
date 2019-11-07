import {
    Schema, json,
    Type, dataType, schemaType,
    tlet, tref, tunion, tint, tfloat, tstring, tstruct, tnull, tvoid, tliteral, tmap
} from 'qtrp-hoshi'

export const contractType: Type = tlet(
    {
        "contract": tunion([
            tref("constant"),
            tref("value"),
            tref("callable"),
            tref("map"),
            tnull(),
        ]),
        "constant": tstruct({
            _t: tliteral("constant"),
            value: dataType,
            subcontract: tref("maybe_map"),
        }),
        "value": tstruct({
            _t: tliteral("value"),
            type: tref("type"),
            subcontract: tref("maybe_map"),
        }),
        "callable": tstruct({
            _t: tliteral("callable"),
            argument: tref("type"),
            retval: tref("type"),
            subcontract: tref("maybe_map"),
        }),
        "map": tmap(tstring(), tref("contract")),
        "maybe_map": tunion([tref("map"), tvoid()]),
        "type": schemaType,
    },
    tref("contract"),
)

export const contractJson: Schema = json(contractType)
