require('./index.html');

import * as potoo from 'potoo';
import * as MQTT from 'paho-mqtt';

function show_time(chan: potoo.Channel<string>) {
    chan.send((new Date()).toLocaleString())
    setTimeout(() => show_time(chan), 999)
}

function make_contract() : potoo.Contract {
    let boingval  = new potoo.Channel<number>().send(4)
    let sliderval = new potoo.Channel<number>().send(5)
    let timechan  = new potoo.Channel<string>()
    show_time(timechan)

    return {
        "description": "A service which provides a greeting.",
        "methods": {
            "hello": {
                _t: "callable",
                argument: {_t: "type-struct", fields: { item: {_t: "type-basic", name: "string", _meta: {description: "item to greet"}} } },
                retval: {_t: "type-basic", name: "string"},
                handler: async (arg: any) => `hello, ${arg.item}!`,
                subcontract: {
                    "description": "Performs a greeting",
                    "ui_tags": "order:1",
                },
            },
            "boing": {
                _t: "callable",
                argument: {_t: "type-basic", name: "null"},
                retval:   {_t: "type-basic", name: "void"},
                handler: async (_: any) => boingval.send((await boingval.get() + 1) % 20),
                subcontract: {
                    "description": "Boing!",
                    "ui_tags": "order:3",
                }
            },
            "boinger": {
                _t: "value",
                type: {_t: "type-basic", name: "float", _meta: {min: 0, max: 20}},
                channel: boingval,
                subcontract: {
                    "ui_tags": "order:4,decimals:0",
                    "stops": {
                        "0": "init",
                        "5": "first",
                        "15": "second",
                    },
                }
            },
            "slider": {
                _t: "value",
                type: {_t: "type-basic", name: "float", _meta: {min: 0, max: 20}},
                channel: sliderval,
                subcontract: {
                    "set": {
                        _t: "callable",
                        argument: {_t: "type-basic", name: "float"},
                        retval:   {_t: "type-basic", name: "void"},
                        handler: async (val: any) => sliderval.send(val as number),
                        subcontract: { },
                    },
                    "ui_tags": "order:5,decimals:1",
                }
            },
            "clock": {
                _t: "value",
                type: { _t: "type-basic", name: "string" },
                subcontract: { "description": "current time" },
                channel: timechan,
            },
        }
    }
}

async function connect(root: string): Promise<potoo.Connection> {
    let paho = new MQTT.Client('ws://' + location.hostname + ':' + Number(location.port) + '/ws', "fidget_" + random_string(8));
    let client = {
        connect: (config: potoo.ConnectConfig) : Promise<void> => new Promise((resolve, reject) => {
            paho.onConnectionLost = (err) => {
                config.on_disconnect()
                console.log(`disconnected! error: ${err.errorMessage}`)
            }
            paho.onMessageArrived = (m) => {
                let msg = {
                    topic: m.destinationName,
                    payload: m.payloadString,
                    retain: m.retained,
                }
                console.log(' [in] ', msg.topic, ': ', msg.payload)
                config.on_message(msg)
            }
            let will = new MQTT.Message(config.will_message.payload)
            will.destinationName = config.will_message.topic
            will.retained        = config.will_message.retain
            paho.connect({
                onSuccess: (con) => resolve(),
                willMessage: will,
                onFailure: (err) => reject(err.errorMessage),
            })
        }),
        publish:   (msg: potoo.Message) => {
            console.log('[out] ', msg.topic, ': ', msg.payload)
            paho.send(msg.topic, msg.payload, 0, msg.retain)
        },
        subscribe: (filter: string) : Promise<void> => new Promise((resolve, reject) => {
            console.log('[sub] ', filter)
            paho.subscribe(filter, {
                onSuccess: (con) => resolve(),
                onFailure: (err) => reject(err.errorMessage),
            })
        }),
    }

    let conn = new potoo.Connection({
        mqtt_client: client,
        root: root,
        on_contract: on_contract
    })
    await conn.connect()
    return conn
}

declare global {
    interface Window { contracts: { [topic: string]: potoo.Contract }; }
}

window.contracts = {}
function on_contract(topic: string, contract: potoo.Contract) {
    window.contracts[topic] = contract;
}

async function server(): Promise<void> {
    document.title += ': server'
    let conn = await connect('/fidget')
    conn.update_contract(make_contract())
}

async function client(): Promise<void> {
    document.title += ': client'
    let conn = await connect('/')
    conn.get_contracts('#')
}

async function do_stuff(f: () => Promise<void>) {
    document.body.innerHTML = 'read your motherfucking console';
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
