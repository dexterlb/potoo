import { expect } from 'chai';
import * as potoo from '../src';
import * as hoshi from 'qtrp-hoshi'

const fs = eval('require("fs")');

describe('universe', () => {
  it('works', () => {
    let result = 6 * 7
    expect(result).equal(42)
  })
})

describe('contracts', () => {
  it('fidget contract is valid', () => {
    let j = hoshi.json
    let contract: potoo.RawContract = {
      "description": potoo.rconst("A service which provides a greeting."),
      "methods": {
        "hello": {
          _t: "callable",
          argument: j(hoshi.tstruct({ item: hoshi.tstring({description: "item to greet"}) })),
          retval: j(hoshi.tstring()),
          subcontract: {
            "description": potoo.rconst("Performs a greeting"),
            "ui_tags": potoo.rconst("order:1"),
          },
        },
        "boing": {
          _t: "callable",
          argument: j(hoshi.tnull()),
          retval:   j(hoshi.tvoid()),
          subcontract: {
            "description": potoo.rconst("Boing!"),
            "ui_tags": potoo.rconst("order:3"),
          }
        },
        "boinger": {
          _t: "value",
          type: j(hoshi.tfloat({min: 0, max: 20})),
          subcontract: {
            "ui_tags": potoo.rconst("order:4,decimals:0"),
          }
        },
        "wooo": {
          _t: "value",
          type: j(hoshi.tfloat({min: 0, max: 20})),
          subcontract: {
            "ui_tags": potoo.rconst("order:4,decimals:2"),
          }
        },
        "slider": {
          _t: "value",
          type: j(hoshi.tfloat({min: 0, max: 20})),
          subcontract: {
            "set": {
              _t: "callable",
              argument: j(hoshi.tfloat()),
              retval:   j(hoshi.tvoid()),
              subcontract: { },
            },
            "ui_tags": potoo.rconst("order:5,decimals:1,speed:99,exp_speed:99"),
          }
        },
        "clock": {
          _t: "value",
          type: j(hoshi.tstring()),
          subcontract: { "description": potoo.rconst("current time") },
        },
      }
    }

    let result = potoo.check(contract);
    if (result != "ok") {
      fs.writeFile("/tmp/typeerr.json", JSON.stringify(result), () => {
        console.log("dumped type error into /tmp/typeerr.json")
      })
    }
    expect(result).to.be.equal("ok")
  })
})
