require('./index.html');

import * as potoo from 'potoo';
import * as MQTT from 'paho-mqtt';
import * as hoshi from 'hoshi';

function con(value: any): potoo.Contract {
    return { _t: "constant", value: value, subcontract: {} }
}

function show_time(chan: potoo.Bus<string>) {
    chan.send((new Date()).toLocaleString())
    setTimeout(() => show_time(chan), 999)
}

async function woo(chan: potoo.Bus<number>) {
    let woo_div = document.getElementById('woo')
    let val = await chan.get()
    chan.send((val + 0.01) % 20)
    setTimeout(() => woo(chan), 10)
    if (woo_div != null) {
        woo_div.innerHTML = "" + val
    }
}

function make_contract() : potoo.Contract {
    let boingval  = new potoo.Bus<number>().send(4)
    let wooval    = new potoo.Bus<number>().send(4)
    let sliderval = new potoo.Bus<number>().send(5)
    let timechan  = new potoo.Bus<string>()
    show_time(timechan)
    woo(wooval)

    return {
        "description": con("A service which provides a greeting."),
        "methods": {
            "hello": {
                _t: "callable",
                argument: hoshi.json({kind: "type-struct", fields: { item: {kind: "type-basic", sub: "string", meta: {description: "item to greet"}} } }),
                retval: hoshi.json({kind: "type-basic", sub: "string"}),
                handler: async (arg: any) => `hello, ${arg.item}!`,
                subcontract: {
                    "description": con("Performs a greeting"),
                    "ui_tags": con("order:1"),
                },
            },
            "boing": {
                _t: "callable",
                argument: hoshi.json({kind: "type-basic", sub: "null"}),
                retval:   hoshi.json({kind: "type-basic", sub: "void"}),
                handler: async (_: any) => boingval.send((await boingval.get() + 1) % 20),
                subcontract: {
                    "description": con("Boing!"),
                    "ui_tags": con("order:3"),
                }
            },
            "boinger": {
                _t: "value",
                type: hoshi.json({kind: "type-basic", sub: "float", meta: {min: 0, max: 20}}),
                bus: boingval,
                subcontract: {
                    "ui_tags": con("order:4,decimals:0"),
                }
            },
            "wooo": {
                _t: "value",
                type: hoshi.json({kind: "type-basic", sub: "float", meta: {min: 0, max: 20}}),
                bus: wooval,
                subcontract: {
                    "ui_tags": con("order:4,decimals:2"),
                }
            },
            "slider": {
                _t: "value",
                type: hoshi.json({kind: "type-basic", sub: "float", meta: {min: 0, max: 20}}),
                bus: sliderval,
                subcontract: {
                    "set": {
                        _t: "callable",
                        argument: hoshi.json({kind: "type-basic", sub: "float"}),
                        retval:   hoshi.json({kind: "type-basic", sub: "void"}),
                        handler: async (val: any) => sliderval.send(val as number),
                        subcontract: { },
                    },
                    "ui_tags": con("order:5,decimals:1,speed:99,exp_speed:99"),
                }
            },
            "clock": {
                _t: "value",
                type: hoshi.json({ kind: "type-basic", sub: "string" }),
                subcontract: { "description": con("current time") },
                bus: timechan,
            },
        }
    }
}

async function connect(root: string, service_root?: string): Promise<potoo.Connection> {
    let paho = new MQTT.Client('ws://' + location.hostname + ':' + Number(location.port) + '/ws', "fidget_" + random_string(8));
    let client = potoo.paho_wrap({
        client: paho,
        message_constructor: MQTT.Message
    })
    let conn = new potoo.Connection({
        mqtt_client: client,
        root: root,
        service_root: service_root,
        on_contract: on_contract
    })
    await conn.connect()
    return conn
}

declare global {
    interface Window {
        contracts: { [topic: string]: potoo.Contract }
        potoo: potoo.Connection
        contract: potoo.Contract
    }
}

window.contracts = {}
window.contract = {}
function on_contract(topic: string, contract: potoo.Contract) {
    window.contracts[topic] = contract;
    window.contract = window.potoo.contract_dirty()
}

async function server(): Promise<void> {
    document.title += ': server'
    let conn = await connect('/things/fidget', "")
    window.potoo = conn
    conn.update_contract(make_contract())
}

async function client(): Promise<void> {
    document.title += ': client'
    let conn = await connect('/')
    window.potoo = conn
    conn.get_contracts('#')
}

async function do_stuff(f: () => Promise<void>) {
    document.body.innerHTML = 'read your motherfucking console. Also woo = <span id="woo"></span>';
    f().then(() => console.log('wooo')).catch((err) => console.log('err ', err));
}

function click(id: string, f: () => Promise<void>) {
    let el = document.getElementById(id)
    if (el) {
        el.onclick = () => do_stuff(f)
    } else {
        console.log('invalid id: ', id)
    }
}

function random_string(n: number) {
    var text = ""
    var chars = "abcdefghijklmnopqrstuvwxyz0123456789"

    for (var i = 0; i < n; i++) {
        text += chars.charAt(Math.floor(Math.random() * chars.length))
    }

    return text;
}

click('client-btn', client)
click('server-btn', server)
