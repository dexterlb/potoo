import {Contract, RawContract, Value, Callable, Call, traverse, encode, isValue, isCallable} from './contracts';
export {Contract, RawContract} from './contracts';
export * from './channel'
import * as mqtt from './mqtt';
export * from './mqtt';
import {typecheck, is_void} from './types'

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
            on_disconnect: () => this.on_disconnect(),
            on_message:    (msg: mqtt.Message) => this.on_message(msg),
            will_message:  this.publish_contract_message(null),
        })
        console.log('connect')
    }

    private service_value_index: { [topic: string]: {
        callback: (v: any) => void,
        value: Value,
    } } = {}
    private callable_index: { [topic: string]: Callable } = {}


    async update_contract(contract: Contract) {
        this.destroy_service()
        traverse(contract, (c, subtopic) => {
            if (isValue(c)) {
                let topic = this.service_topic('_value', subtopic)
                let f = (v: any) => this.publish_value(topic, c, v)
                this.service_value_index[topic] = {
                    callback: f,
                    value: c,
                }

                c.channel.subscribe(f)
                return
            }
            if (isCallable(c)) {
                let topic = this.service_topic('_call', subtopic)
                this.callable_index[topic] = c
                this.mqtt_client.subscribe(topic)
                return
            }
        })

        this.publish_contract(contract)

        this.force_publish_all_values()
    }

    private force_publish_all_values(): void {
        Object.keys(this.service_value_index).forEach(topic => {
            let v = this.service_value_index[topic]
            v.callback(v.value.channel.get())
        })
    }

    private destroy_service(): void {
        Object.keys(this.service_value_index).forEach(topic => {
            let v = this.service_value_index[topic]
            v.value.channel.unsubscribe(v.callback)
        })
    }

    private on_disconnect(): void {
        this.destroy_service()
        console.log('disconnect')
    }

    private on_message(message: mqtt.Message) {
        if (message.topic in this.callable_index) {
            let c = this.callable_index[message.topic]
            // TODO: insert typecheck with the io-ts library here.
            let request = JSON.parse(message.payload) as Call
            typecheck(c.argument, request.argument)
            let result = c.handler(request.argument)
            typecheck(c.retval, result)
            if (!is_void(c.retval)) {
                this.publish_reply(request.topic, request.token, result)
            }
            return
        }
        console.log('unknown message: ', message)
    }

    private publish_reply(topic: mqtt.Topic, token: string, result: any): void {
        this.mqtt_client.publish({
            topic: mqtt.join_topics('_reply', topic),
            retain: false,
            payload: JSON.stringify({token: token, result: result}),
        })
    }

    private publish_value(topic: mqtt.Topic, c: Value, v: any): void {
        typecheck(v, c.type)
        this.mqtt_client.publish({
            topic: topic,
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
