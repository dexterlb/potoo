import {Message, Client, ConnectConfig} from './mqtt'

export type Qos = 0 | 1 | 2
export type PahoBytes = ArrayBuffer | Int8Array | Uint8Array | Uint8ClampedArray | Int16Array | Uint16Array | Int32Array | Uint32Array | Float32Array | Float64Array

export interface PahoMessageConstructor {
    new(payload: string | PahoBytes): PahoMessage
}

export interface PahoMessage extends PahoMessageData {
    payloadString: string
    payloadBytes: PahoBytes
}

export interface PahoMessageData {
    qos: Qos
    retained: boolean
    destinationName: string
    duplicate: boolean
}

export interface PahoError {
    errorMessage: string
    errorCode: number
    invocationContext: object
}

export interface PahoSuccess {
    invocationContext: object
}

export interface PahoConnectionOptions {
    onSuccess?: (suc: PahoSuccess) => void
    onFailure?: (err: PahoError)   => void
    timeout?: number
    userName?: string
    password?: string
    willMessage?: PahoMessage
    keepAliveInterval?: number
    cleanSession?: boolean
    useSSL?: boolean
    invocationContext?: object
    uris?: Array<string>
}

export interface PahoUnsubscribeOptions extends PahoConnectionOptions {
    invocationContext?: object
}

export interface PahoSubscribeOptions extends PahoConnectionOptions {
    qos: Qos
    invocationContext?: object
}

export interface PahoClient {
    connect:          (opts: PahoConnectionOptions) => void
    send:             (topic: string, payload: string, qos: Qos, retained: boolean) => void
    onMessageArrived: (m: PahoMessage) => void
    onConnectionLost: (err: PahoError) => void
    subscribe:        (filter: string, opts: PahoSubscribeOptions) => void
    unsubscribe:      (filter: string, opts: PahoUnsubscribeOptions) => void
}

export interface PahoWrapOptions {
    client:              PahoClient
    message_constructor: PahoMessageConstructor
    on_disconnect?:      (err: PahoError) => void
    on_connect?:         () => void
    subscribe_qos?:      Qos
    message_qos?:        Qos
    debug?:              boolean
    connection_opts?:    PahoConnectionOptions
}

export function paho_wrap(opts: PahoWrapOptions): Client {
    let subscribe_qos: Qos = 0
    let message_qos: Qos = 0
    let on_disconnect: (err: PahoError) => void = err => {}
    let on_connect: () => void = () => {}
    let dbg = (...args: any[]) => {}
    if (opts.on_disconnect) { on_disconnect = opts.on_disconnect }
    if (opts.on_connect) { on_connect = opts.on_connect }
    if (opts.subscribe_qos) { subscribe_qos = opts.subscribe_qos }
    if (opts.message_qos) { message_qos = opts.message_qos }
    if (opts.debug) {
        dbg = (...args: any[]) => {
            console.log(...args)
        }
    }
    let paho = opts.client
    let conn_data: PahoConnectionOptions = {}

    if (opts.connection_opts) {
        Object.assign(conn_data, opts.connection_opts)
    }

    return {
        connect: (config: ConnectConfig): Promise<void> => new Promise((resolve, reject) => {
            paho.onConnectionLost = (err) => {
                on_disconnect(err)
                dbg(`disconnected! error: ${err.errorMessage}`)
                config.on_disconnect()
            }
            paho.onMessageArrived = (m) => {
                let msg = {
                    topic: m.destinationName,
                    payload: m.payloadString,
                    retain: m.retained,
                }
                dbg(' [in] ', msg.topic, ': ', msg.payload)
                config.on_message(msg)
            }
            conn_data.onSuccess = (con) => {
                resolve()
                if (opts.connection_opts && opts.connection_opts.onSuccess) {
                    opts.connection_opts.onSuccess(con)
                }
            }
            conn_data.onFailure = (err) => {
                reject(err.errorMessage)
                on_disconnect(err)
                if (opts.connection_opts && opts.connection_opts.onFailure) {
                    opts.connection_opts.onFailure(err)
                }
            }
            if (config.will_message) {
                let msg = new opts.message_constructor(config.will_message.payload)
                msg.destinationName = config.will_message.topic
                msg.qos = message_qos
                msg.retained = config.will_message.retain
                conn_data.willMessage = msg
            }
            dbg('[con]')
            paho.connect(conn_data)
            on_connect()
        }),
        publish:   (msg: Message) => {
            dbg('[out] ', msg.topic, ': ', msg.payload)
            paho.send(msg.topic, msg.payload, message_qos, msg.retain)
        },
        subscribe: (filter: string) : Promise<void> => new Promise((resolve, reject) => {
            dbg('[sub] ', filter)
            paho.subscribe(filter, {
                onSuccess: (con) => resolve(),
                onFailure: (err) => reject(err.errorMessage),
                qos: subscribe_qos,
            })
        }),
        unsubscribe: (filter: string) : Promise<void> => new Promise((resolve, reject) => {
            dbg('[uns] ', filter)
            paho.unsubscribe(filter, {
                onSuccess: (con) => resolve(),
                onFailure: (err) => reject(err.errorMessage),
            })
        }),
    }
}
