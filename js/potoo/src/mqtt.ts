export interface Client {
    connect: (config: ConnectConfig) => Promise<void>,
    publish: (message: Message)      => void,
    subscribe: (filter: string)      => Promise<void>,
}

export interface ConnectConfig {
    on_disconnect:   () => void,
    on_message:      (message: Message) => void,
    will_message:    Message,
}

export interface Message {
    topic: string,
    payload: string,
    retain: boolean,
}
