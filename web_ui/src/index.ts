require('./index.html');

let fragment = new URLSearchParams(window.location.hash.substr(1));
let theme = fragment.get('theme');

if (theme == 'slick') {
    require('./styles/slick.scss');
} else {
    require('./styles/main.scss');
}

let elm = require('./Main.elm')

import * as potoo from 'qtrp-potoo';
import * as MQTT from 'paho-mqtt';

type ElmApp = any   // he he

interface Context {
    paho: MQTT.Client
    client: potoo.Client
    conn: potoo.Connection
    app: ElmApp
}

function send(whom: any, msg: any) {
    // console.log('send ', msg)
    whom.send(msg)
}

function init(app: ElmApp, url: string, root: string): Context {
    let paho = new MQTT.Client(url, "ui_" + random_string(8));
    let client = potoo.paho_wrap({
        client: paho,
        message_constructor: MQTT.Message,
        debug: false,
        on_disconnect: () => {
            send(app.ports.incoming, {
                _t: 'disconnected',
            })
        },
    })

    let events = {
        on_contract: () => {}
    }

    let conn = new potoo.Connection({
        mqtt_client: client,
        root: root,
        on_contract: contract => {
            send(app.ports.incoming, {
                _t: 'got_contract',
                contract: events.on_contract(),
            })
        },
    })

    events.on_contract = () => {
        return conn.contract_dirty()
    }

    return {
        paho: paho,
        client: client,
        conn: conn,
        app: app,
    }
}

async function process_message(ctx: Context, msg: any): Promise<void> {
    switch (msg._t) {
        case 'connect':
            Object.assign(ctx, init(ctx.app, msg.url, msg.root))
            await ctx.conn.connect()
            send(ctx.app.ports.incoming, {
                _t: 'connected',
            })
            await ctx.conn.get_contracts('#')
            break
        case 'subscribe':
            let chan = ctx.conn.value(msg.topic)
            if (chan) {
                chan.subscribe(v => send(ctx.app.ports.incoming, {
                    _t: 'got_value',
                    path: msg.topic,
                    value: v,
                }))
            } else {
                console.log('tried subscribing to unknown value ', msg.topic)
            }
            break
        case 'call':
            send(ctx.app.ports.incoming, {
                _t: 'call_result',
                value: await ctx.conn.call(msg.path, msg.argument),
                token: msg.token,
            })
            break
        default:
            throw new Error('what do I do with ' + msg._t)
    }
}

function main() {
    let app = elm.Elm.Main.init({ node: document.documentElement });

    let ctx = init(app, 'ws://example.com/ws', '')

    app.ports.outgoing.subscribe((msg: any) => {
        process_message(ctx, msg).then(() => {
        }).catch(err => {
            console.log('error while processing ', msg, ': ', err)
        })
    });

    requestAnimationFrame(animate(app));
}

function animate(app: ElmApp) {
    return (time: number) => {
        app.ports.rawTimes.send(time / 1000);
        requestAnimationFrame(animate(app));
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

main()
