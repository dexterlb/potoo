import {Contract, RawContract, Value, RawCallable, Callable, Call, CallResponse, traverse, encode, decode, isValue, isCallable, attach_at, MapContract} from './contracts';
export {Contract, RawContract, check} from './contracts';
import {Bus} from './bus'
import {contractJson} from './meta'
export * from './bus'
export * from './sugar'
import * as mqtt from './mqtt';
export * from './mqtt';
export * from './mqtt_wrappers';
import * as hoshi from 'qtrp-hoshi'

export interface ConnectionOptions {
    mqtt_client: mqtt.Client,
    root: mqtt.Topic,
    service_root?: mqtt.Topic,
    on_contract?: (topic: mqtt.Topic, contract: Contract) => void,
    call_timeout?: number,
}

export interface PersistentValueStatusEvent {
    event: "offline" | "online",
}

export interface PersistentValueUpdateEvent {
    event: "update",
    value: hoshi.Data,
}

export type PersistentValueEvent = PersistentValueStatusEvent
                                 | PersistentValueUpdateEvent

export class Connection {
    private reply_topic: string

    private mqtt_client: mqtt.Client
    private root: mqtt.Topic
    private service_root: mqtt.Topic
    private is_service: boolean = false
    private on_contract: (topic: mqtt.Topic, contract: Contract) => void
    private call_timeout: number
    private dummyChan: Bus<any>
    private contract_encoder: hoshi.Encoder
    private contract_decoder: hoshi.Decoder

    constructor(options: ConnectionOptions) {
        this.reply_topic  = random_string(16)
        this.mqtt_client  = options.mqtt_client
        this.root         = options.root
        if (options.service_root != undefined) {
            this.service_root = options.service_root
            this.is_service = true
        }
        this.on_contract  = options.on_contract  || ((t, c) => {})
        this.call_timeout = options.call_timeout || 25000

        let dec = hoshi.decoder(contractJson)
        let enc = hoshi.encoder(contractJson)
        if ('error' in dec) {
            throw new Error("unable to initialise contract decoder")
        }
        if ('error' in enc) {
            throw new Error("unable to initialise contract encoder")
        }
        this.contract_encoder = enc
        this.contract_decoder = dec
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
        callback: (v: hoshi.Data) => void,
        value: Value,
    } } = {}
    private service_callable_index: { [topic: string]: ServiceCallable } = {}


    async update_contract(contract: Contract) {
        if (!this.is_service) {
            throw new Error('cannot publish contract without service root')
        }
        this.destroy_service()
        let side_effects: Array<Promise<void>> = []
        traverse(contract, (c, subtopic) => {
            if (isValue(c)) {
                let topic = this.service_topic('_value', subtopic)
                let f = (v: any) => {
                    let encoder = hoshi.encoder(c.type)
                    if (hoshi.is_err(encoder)) {
                        side_effects.unshift(Promise.reject(encoder.error));
                        return
                    }
                    this.publish_value(topic, {value: c, encoder: encoder}, v)
                }

                this.service_value_index[topic] = {
                    callback: f,
                    value: c,
                }

                side_effects.push(c.bus.subscribe(f))
                return
            }
            if (isCallable(c)) {
                let topic = this.service_topic('_call', subtopic)
                let argDecoder = hoshi.decoder(c.argument)
                if (hoshi.is_err(argDecoder)) {
                    side_effects.unshift(Promise.reject(argDecoder.error))
                    return
                }
                let retEncoder = hoshi.encoder(c.retval)
                if (hoshi.is_err(retEncoder)) {
                    side_effects.unshift(Promise.reject(retEncoder.error))
                    return
                }
                this.service_callable_index[topic] = {
                    callable: c,
                    argDecoder: argDecoder,
                    retEncoder: retEncoder,
                }
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
                v.callback(await v.value.bus.get())
            })())
        })
        await Promise.all(side_effects)
    }

    private destroy_service(): void {
        Object.keys(this.service_value_index).forEach(topic => {
            let v = this.service_value_index[topic]
            v.value.bus.unsubscribe(v.callback)
        })
    }

    private on_disconnect(): void {
        this.destroy_service()
        console.log('disconnect')
    }

    private on_message(message: mqtt.Message) {
        if (message.topic in this.value_index) {
            let { value, decoder } = this.value_index[message.topic]

            let result = decoder(message.payload)
            if (hoshi.is_err(result)) {
                console.log("error processing value: ", result.error)
                return
            }

            value.bus.send(result.term)

            if (message.topic in this.persistent_value_index) {
                this.persistent_value_index[message.topic].send({
                    event: "update",
                    value: result.term,
                })
            }
            return
        }

        if (message.topic in this.service_callable_index) {
            let c = this.service_callable_index[message.topic]
            let [topic, token, argData] = limited_split(message.payload, ' ', 3)
            let decArg = c.argDecoder(argData)
            if (hoshi.is_err(decArg)) {
                console.log("error processing call argument: ", decArg.error)
                return
            }
            let arg = decArg.term

            c.callable.handler(arg).then(retval => {
                let data = c.retEncoder(retval)
                if (hoshi.is_err(data)) {
                    console.log("error encoding call reply: ", data.error)
                    return
                }
                if (!hoshi.is_void(c.callable.retval.t)) {
                    this.publish_reply(topic, token, data)
                }
            }).catch(err => {
                console.log('error while processing call to ', message.topic, ': ', err)
            })
            return
        }

        if (message.topic == mqtt.join_topics('_reply', this.reply_topic)) {
            let [token, retvalData] = limited_split(message.payload, ' ', 2)
            if (!(token in this.active_calls)) {
                console.log('someone responded to an unknown call: ', token)
                return
            }

            this.active_calls[token].resolve(retvalData)
            delete this.active_calls[token]
            return
        }

        let contract_topic = mqtt.strip_topic('_contract', message.topic)
        if (contract_topic != null) {
            let raw_contract = this.contract_decoder(message.payload)
            if (hoshi.is_err(raw_contract)) {
                console.log('received malformed contract', raw_contract)
                return
            }
            this.incoming_contract(contract_topic, raw_contract.term as RawContract)
            return
        }

        console.log('unknown message: ', message)
    }

    public async get_contracts(topic: mqtt.Topic) {
        await this.mqtt_client.subscribe(this.client_topic('_contract', topic))
    }

    public value(topic: string): Bus<hoshi.Data> | null {
        let value_topic = this.client_topic('_value', topic)
        if (value_topic in this.value_index) {
            return this.value_index[value_topic].value.bus
        }
        return null
    }

    public value_persistent(topic: string): Bus<PersistentValueEvent> {
        let value_topic = this.client_topic('_value', topic)
        if (!(value_topic in this.persistent_value_index)) {
            this.persistent_value_index[value_topic] = this.make_value_bus<PersistentValueEvent>(value_topic)
            this.persistent_value_index[value_topic].send({event: "online"})
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

    public call(topic: string, argument: hoshi.Data): Promise<hoshi.Data> {
        if (!(topic in this.callable_index)) {
            return Promise.reject("topic ${topic} not available for call")
        }
        return this.callable_index[topic].callable.handler(argument)
    }

    private make_value_bus<T>(value_topic: string): Bus<T>{
        return new Bus<T>({
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
    private callable_index: { [topic: string]: ClientCallable } = {}
    private value_index: { [topic: string]: ClientValue } = {}
    private persistent_value_index: { [topic: string]: Bus<PersistentValueEvent> } = {}
    private incoming_contract(topic: mqtt.Topic, raw: RawContract) {
        this.destroy_contract(topic)
        let contract = decode(raw, {
            valueBus: c => this.dummyChan,
            callHandler: c => async x => undefined,
        })
        let fail = () => this.destroy_contract(topic)

        if (contract != null) {
            this.contract_index[topic] = contract
            traverse(contract, (c, subtopic) => {
                let full_topic = mqtt.join_topics(topic, subtopic)
                if (isValue(c)) {
                    let value_topic = this.client_topic('_value', full_topic)
                    c.bus = this.make_value_bus<hoshi.Data>(value_topic)
                    let decoder = hoshi.decoder(c.type)
                    if (hoshi.is_err(decoder)) {
                        fail()
                        console.log("unable to create decoder for value in incoming contract: ", decoder)
                        return
                    }
                    this.value_index[value_topic] = { value: c, decoder: decoder }

                    if (value_topic in this.persistent_value_index) {
                        this.persistent_value_index[value_topic].send({event: "online"})
                    }

                    return
                }
                if (isCallable(c)) {
                    let retDecoder = hoshi.decoder(c.retval)
                    if (hoshi.is_err(retDecoder)) {
                        fail()
                        console.log("unable to create return value decoder for callable in incoming contract: ", retDecoder)
                        return
                    }
                    let argEncoder = hoshi.encoder(c.argument)
                    if (hoshi.is_err(argEncoder)) {
                        fail()
                        console.log("unable to create argument encoder for callable in incoming contract: ", argEncoder)
                        return
                    }
                    let sc = { callable: c, retDecoder: retDecoder, argEncoder: argEncoder }
                    this.callable_index[full_topic] = sc
                    c.handler = arg => this.perform_call(sc, full_topic, arg)
                    return
                }
            })
        }

        this.on_contract(topic, contract)
    }

    private active_calls: { [token: string]: Promiser<string> } = {}
    private perform_call(sc: ClientCallable, topic: mqtt.Topic, arg: hoshi.Data): Promise<hoshi.Data> {
        return new Promise<hoshi.Data>((resolve, reject) => {
            let argData = sc.argEncoder(arg)
            if (hoshi.is_err(argData)) {
                reject(argData.error);
                return
            }

            let token = random_string(16)

            this.mqtt_client.publish({
                topic: this.client_topic('_call', topic),
                retain: false,
                payload: this.reply_topic + ' ' + token + ' ' + argData,
            })

            if (hoshi.is_void(sc.callable.retval.t)) {
                resolve()
                return
            }

            let resolve_retval = (retvalData: string) => {
                let retval = sc.retDecoder(retvalData)
                if (hoshi.is_err(retval)) {
                    reject(retval.error);
                    return
                }
                resolve(retval.term)
            }
            this.active_calls[token] = {resolve: resolve_retval, reject: reject}
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
            let value_topic = mqtt.join_topic_list(['_value', topic, subtopic])
            delete this.value_index[value_topic]

            if (value_topic in this.persistent_value_index) {
                this.persistent_value_index[value_topic].send({event: "offline"})
            }
        })
        delete this.contract_index[topic]
        // hooray for the garbage collector :)
    }

    private publish_reply(topic: mqtt.Topic, token: string, replyData: string): void {
        this.mqtt_client.publish({
            topic: mqtt.join_topics('_reply', topic),
            retain: false,
            payload: token + ' ' + replyData,
        })
    }

    private publish_value(topic: mqtt.Topic, sv: ServiceValue, v: hoshi.Data): void {
        let data = sv.encoder(v)
        if (hoshi.is_err(data)) {
            console.log("unable to encode value: ", data)
            return
        }

        this.mqtt_client.publish({
            topic: topic,
            retain: true,
            payload: data,
        })
    }

    private publish_contract(contract: Contract) {
        return this.mqtt_client.publish(this.publish_contract_message(contract))
    }

    private publish_contract_message(contract: Contract): mqtt.Message {
        let payload = this.contract_encoder(contract as unknown as hoshi.Data)
        if (typeof payload != 'string') {
            console.log('cannot publish invalid contract', payload)
            // FIXME - maybe we shouldn't blow up everything
            throw new Error('invalid outbound contract')
        }
        return {
            topic:   this.service_topic('_contract'),
            retain:  true,
            payload: payload,
        }
    }

    private service_topic(prefix: mqtt.Topic, suffix: mqtt.Topic = ""): mqtt.Topic {
        return mqtt.join_topic_list([prefix, this.root, this.service_root, suffix])
    }

    private client_topic(prefix: mqtt.Topic, suffix: mqtt.Topic = ""): mqtt.Topic {
        return mqtt.join_topic_list([prefix, this.root, suffix])
    }
}

interface Promiser<T> {
    resolve: (v: T)     => void,
    reject:  (err: any) => void,
}

interface ServiceValue {
    value: Value,
    encoder: hoshi.Encoder,
}

interface ServiceCallable {
    callable: Callable,
    argDecoder: hoshi.Decoder,
    retEncoder: hoshi.Encoder,
}

interface ClientValue {
    value: Value,
    decoder: hoshi.Decoder,
}

interface ClientCallable {
    callable: Callable,
    retDecoder: hoshi.Decoder,
    argEncoder: hoshi.Encoder,
}

function random_string(n: number) {
    var text = ""
    var chars = "abcdefghijklmnopqrstuvwxyz0123456789"

    for (var i = 0; i < n; i++) {
        text += chars.charAt(Math.floor(Math.random() * chars.length))
    }

    return text;
}

function limited_split(x: string, sep: string, n: number): Array<string> {
    let result: Array<string> = []
    for (let i = 0; i < n; i++) {
        let idx = x.indexOf(sep)
        if (idx >= 0 && i < n - 1) {
            result.push(x.substr(0, idx))
            x = x.substr(idx + 1)
        } else {
            result.push(x)
            x = ''
        }
    }
    return result
}
