import {Contract, RawContract, Value, Callable, traverse, encode, isValue, isCallable} from './contracts';
export {Contract, RawContract} from './contracts';
export * from './channel'
import * as mqtt from './mqtt';
export * from './mqtt';
import {typecheck} from './types'

export function foo() : string {
    return 'this is the foo';
}

export class Connection {
    private reply_topic: string
    constructor(private mqtt_client: mqtt.Client, private root: string, private service_root: string = "") {
        this.reply_topic = random_string(15)
    }

    private root_topic: string

    async connect(): Promise<void> {
        await this.mqtt_client.connect({
            on_disconnect: this.on_disconnect,
            on_message:    this.on_message,
            will_message:  this.publish_contract_message(null),
        })
        console.log('connect')
    }

    private service_value_index: { [topic: string]: {
        callback: (v: any) => void,
        value: Value,
    } } = {}

    private service_channel_subscriptions: { [topic: string]: (v: any) => void } = {}
    async update_contract(contract: Contract) {
        this.destroy_service()
        traverse(contract, (c, topic) => {
            if (isValue(c)) {
                let f = (v: any) => this.publish_value(topic, c, v)
                this.service_value_index[this.service_topic(topic)] = {
                    callback: f,
                    value: c,
                }
                c.channel.subscribe(f)
            }
        })

        this.publish_contract(contract)
    }

    private destroy_service() {
        Object.keys(this.service_value_index).forEach(topic => {
            let v = this.service_value_index[topic].value
            v.channel.unsubscribe(this.service_value_index[topic].callback)
        })
    }

    private on_disconnect() {
        this.destroy_service()
        console.log('disconnect')
    }

    private on_message(message: mqtt.Message) {
        console.log('message: ', message)
    }

    private publish_value(topic: mqtt.Topic, c: Value, v: any) {
        typecheck(v, c.type)
        this.mqtt_client.publish({
            topic: this.service_topic('_value', topic),
            retain: true,
            payload: JSON.stringify(v),
        })
    }

    private publish_contract(contract: Contract) {
        this.mqtt_client.publish(this.publish_contract_message(contract))
    }

    private publish_contract_message(contract: Contract): mqtt.Message {
        return {
            topic:   this.service_topic('_contract'),
            retain:  true,
            payload: JSON.stringify(encode(contract)),
        }
    }

    private service_topic(prefix: mqtt.Topic, suffix: mqtt.Topic = ""): mqtt.Topic {
        return mqtt.join_topic_list([prefix, this.root, this.service_root, suffix])
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
