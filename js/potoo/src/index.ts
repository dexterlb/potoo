import {Contract, RawContract, Value, RawCallable, Callable, Call, CallResponse, traverse, encode, decode, isValue, isCallable, attach_at, MapContract} from './contracts';
export {Contract, RawContract} from './contracts';
import {Channel} from './channel'
export * from './channel'
import * as mqtt from './mqtt';
export * from './mqtt';
export * from './mqtt_wrappers';
import {typecheck, is_void} from './types'

export interface ConnectionOptions {
    mqtt_client: mqtt.Client,
    root: mqtt.Topic,
    service_root?: mqtt.Topic,
    on_contract?: (topic: mqtt.Topic, contract: Contract) => void,
    call_timeout?: number,
}

export class Connection {
    private reply_topic: string

    private mqtt_client: mqtt.Client
    private root: mqtt.Topic
    private service_root: mqtt.Topic
    private is_service: boolean = false
    private on_contract: (topic: mqtt.Topic, contract: Contract) => void
    private call_timeout: number
    private dummyChan: Channel<any>

    constructor(options: ConnectionOptions) {
        this.reply_topic  = random_string(16)
        this.mqtt_client  = options.mqtt_client
        this.root         = options.root
        if (options.service_root != undefined) {
            this.service_root = options.service_root
            this.is_service = true
        }
        this.on_contract  = options.on_contract  || ((t, c) => {})
        this.call_timeout = options.call_timeout || 5000
    }

    private root_topic: string

    async connect(): Promise<void> {
        let config: mqtt.ConnectConfig = {
            on_disconnect: () => this.on_disconnect(),
            on_message:    (msg: mqtt.Message) => this.on_message(msg),
        }
        if (this.is_service) {
            config.will_message = this.publish_contract_message(null)
        }
        await this.mqtt_client.connect(config)
        await this.mqtt_client.subscribe(mqtt.join_topics('_reply', this.reply_topic))
        console.log('connect')
    }

    private service_value_index: { [topic: string]: {
        callback: (v: any) => void,
        value: Value,
    } } = {}
    private service_callable_index: { [topic: string]: Callable } = {}


    async update_contract(contract: Contract) {
        if (!this.is_service) {
            throw new Error('cannot publish contract without service root')
        }
        this.destroy_service()
        let side_effects: Array<Promise<void>> = []
        traverse(contract, (c, subtopic) => {
            if (isValue(c)) {
                let topic = this.service_topic('_value', subtopic)
                let f = (v: any) => this.publish_value(topic, c, v)
                this.service_value_index[topic] = {
                    callback: f,
                    value: c,
                }

                side_effects.push(c.channel.subscribe(f))
                return
            }
            if (isCallable(c)) {
                let topic = this.service_topic('_call', subtopic)
                this.service_callable_index[topic] = c
                side_effects.push(this.mqtt_client.subscribe(topic))
                return
            }
        })

        await Promise.all(side_effects)

        this.publish_contract(contract)

        await this.force_publish_all_values()
    }

    private async force_publish_all_values(): Promise<void> {
        let side_effects: Array<Promise<void>> = []
        Object.keys(this.service_value_index).forEach(topic => {
            let v = this.service_value_index[topic]
            side_effects.push((async () => {
                v.callback(await v.value.channel.get())
            })())
        })
        await Promise.all(side_effects)
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
        if (message.topic in this.value_index) {
            let v = this.value_index[message.topic]
            let value = JSON.parse(message.payload)
            typecheck(v.type, value)
            v.channel.send(value)
            if (message.topic in this.persistent_value_index) {
                this.persistent_value_index[message.topic].send(value)
            }
            return
        }

        if (message.topic in this.service_callable_index) {
            let c = this.service_callable_index[message.topic]
            // TODO: insert typecheck with the io-ts library here.
            let request = JSON.parse(message.payload) as Call
            typecheck(c.argument, request.argument)
            c.handler(request.argument).then(result => {
                typecheck(c.retval, result)
                if (!is_void(c.retval)) {
                    this.publish_reply(request.topic, request.token, result)
                }
            }).catch(err => {
                console.log('error while processing call to ', message.topic, ': ', err)
            })
            return
        }

        if (message.topic == mqtt.join_topics('_reply', this.reply_topic)) {
            // TODO: insert typecheck with the io-ts library here.
            let response = JSON.parse(message.payload) as CallResponse
            if (!(response.token in this.active_calls)) {
                console.log('someone responded to an unknown call: ', response.token)
                return
            }
            this.active_calls[response.token].resolve(response.result)
            delete this.active_calls[response.token]
            return
        }

        let contract_topic = mqtt.strip_topic('_contract', message.topic)
        if (contract_topic != null) {
            let raw_contract = JSON.parse(message.payload) as RawContract
            // TODO: insert typecheck with the io-ts library here.
            this.incoming_contract(contract_topic, raw_contract)
            return
        }

        console.log('unknown message: ', message)
    }

    public async get_contracts(topic: mqtt.Topic) {
        await this.mqtt_client.subscribe(this.client_topic('_contract', topic))
    }

    public value(topic: string): Channel<any> | null {
        let value_topic = this.client_topic('_value', topic)
        if (value_topic in this.value_index) {
            return this.value_index[value_topic].channel
        }
        return null
    }

    public value_persistent(topic: string): Channel<any> {
        let value_topic = this.client_topic('_value', topic)
        if (!(value_topic in this.persistent_value_index)) {
            this.persistent_value_index[value_topic] = this.make_value_channel(value_topic)
        }
        return this.persistent_value_index[value_topic]
    }

    public contract_dirty(): MapContract {
        let result: MapContract = {}
        Object.keys(this.contract_index).forEach(topic => {
            result = attach_at(result, topic, this.contract_index[topic])
        })
        return result
    }

    public call(topic: string, argument: any): Promise<any> {
        if (!(topic in this.callable_index)) {
            return Promise.reject("topic ${topic} not available for call")
        }
        return this.callable_index[topic].handler(argument)
    }

    private make_value_channel(value_topic: string): Channel<any>{
        return new Channel<any>({
            on_first_subscribed: async () => {
                await this.mqtt_client.subscribe(value_topic)
            },
            on_last_unsubscribed: async () => {
                if (value_topic in this.persistent_value_index) {
                    return
                }
                this.mqtt_client.unsubscribe(value_topic)
            },
            on_subscribed: async () => {},
            on_unsubscribed: async () => {},
        })
    }

    private contract_index: { [topic: string]: Contract } = {}
    private callable_index: { [topic: string]: Callable } = {}
    private value_index: { [topic: string]: Value } = {}
    private persistent_value_index: { [topic: string]: Channel<any> } = {}
    private incoming_contract(topic: mqtt.Topic, raw: RawContract) {
        this.destroy_contract(topic)
        let contract = decode(raw, {
            valueChannel: c => this.dummyChan,
            callHandler: c => async x => undefined,
        })

        if (contract != null) {
            this.contract_index[topic] = contract
            traverse(contract, (c, subtopic) => {
                let full_topic = mqtt.join_topics(topic, subtopic)
                if (isValue(c)) {
                    let value_topic = this.client_topic('_value', full_topic)
                    c.channel = this.make_value_channel(value_topic)
                    this.value_index[value_topic] = c
                    return
                }
                if (isCallable(c)) {
                    this.callable_index[full_topic] = c
                    c.handler = arg => this.perform_call(c, full_topic, arg)
                    return
                }
            })
        }

        this.on_contract(topic, contract)
    }

    private active_calls: { [token: string]: Promiser<any> } = {}
    private perform_call(c: RawCallable, topic: mqtt.Topic, arg: any): Promise<any> {
        typecheck(arg, c.argument)
        return new Promise<any>((resolve, reject) => {
            let token = random_string(16)

            this.mqtt_client.publish({
                topic: this.client_topic('_call', topic),
                retain: false,
                payload: JSON.stringify({topic: this.reply_topic, token: token, argument: arg}),
            })

            if (is_void(c.retval)) {
                resolve()
                return
            }

            let resolve_result = (result: any) => {
                typecheck(result, c.retval)
                resolve(result)
            }
            this.active_calls[token] = {resolve: resolve_result, reject: reject}
            setTimeout(() => {
                if (token in this.active_calls) {
                    delete this.active_calls[token]
                    reject(new Error('timeout'))
                }
            }, this.call_timeout)
        })
    }

    private destroy_contract(topic: mqtt.Topic) {
        if (!(topic in this.contract_index)) {
            return
        }
        traverse(this.contract_index[topic], (c, subtopic) => {
            delete this.callable_index[mqtt.join_topics(topic, subtopic)]
            delete this.value_index[mqtt.join_topic_list(['_value', topic, subtopic])]
        })
        delete this.contract_index[topic]
        // hooray for the garbage collector :)
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
        return this.mqtt_client.publish(this.publish_contract_message(contract))
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

    private client_topic(prefix: mqtt.Topic, suffix: mqtt.Topic = ""): mqtt.Topic {
        return mqtt.join_topic_list([prefix, this.root, suffix])
    }
}

interface Subscription {
    persistent: boolean,
    channel: Channel<any>,
}

interface Promiser<T> {
    resolve: (v: T)     => void,
    reject:  (err: any) => void,
}

function random_string(n: number) {
    var text = ""
    var chars = "abcdefghijklmnopqrstuvwxyz0123456789"

    for (var i = 0; i < n; i++) {
        text += chars.charAt(Math.floor(Math.random() * chars.length))
    }

    return text;
}
