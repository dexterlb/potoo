require('./index.html');

import * as potoo from 'potoo';
import * as MQTT from 'paho-mqtt';

async function stuff() {
    let paho = new MQTT.Client('ws://' + location.hostname + ':' + Number(location.port) + '/ws', "clientId");
    let client = {
        connect: (config: potoo.ConnectConfig) : Promise<void> => new Promise((resolve, reject) => {
            paho.onConnectionLost = config.on_disconnect
            paho.onMessageArrived = (m) => config.on_message({
                topic: m.destinationName,
                payload: m.payloadString,
                retain: m.retained,
            })
            let will = new MQTT.Message(config.will_message.payload)
            will.destinationName = config.will_message.topic
            will.retained        = config.will_message.retain
            paho.connect({
                onSuccess: (con) => resolve(),
                willMessage: will,
                onFailure: (err) => reject(err.errorMessage),
            })
        }),
        publish:   (msg: potoo.Message) => paho.send(msg.topic, msg.payload, 0, msg.retain),
        subscribe: (filter: string) : Promise<void> => new Promise((resolve, reject) => {
            paho.subscribe(filter, {
                onSuccess: (con) => resolve(),
                onFailure: (err) => reject(err.errorMessage),
            })
        }),
    }

    let conn = new potoo.Connection(client, '/fidget')
    await conn.connect()
}

document.body.innerHTML = potoo.foo();
stuff().then(() => console.log('wooo')).catch((err) => console.log('err ', err));
