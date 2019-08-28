export type Topic = string

export interface Client {
    connect: (config: ConnectConfig) => Promise<void>,
    publish: (message: Message)      => void,
    subscribe: (filter: Topic)       => Promise<void>,
    unsubscribe: (filter: Topic)     => Promise<void>,
}

export interface ConnectConfig {
    on_disconnect:   () => void,
    on_message:      (message: Message) => void,
    will_message?:    Message,
}

export interface Message {
    topic: Topic,
    payload: string,
    retain: boolean,
}

export function join_topic_list(topics: Array<Topic>): Topic {
    return topics.reduce(join_topics, '')
}

export function join_topics(a: Topic, b: Topic): Topic {
    a = trim_topic(a)
    b = trim_topic(b)
    if (a == '') return b;
    if (b == '') return a;
    return a + '/' + b
}

export function trim_topic(t: Topic): Topic {
    return t.replace(/^\/+|\/+$/g, '')
}

export function strip_topic(prefix: Topic, t: Topic): Topic | null {
    prefix = trim_topic(prefix)
    t = trim_topic(t)
    if (prefix == t) {
        return ''
    }
    prefix += '/'
    if (t.startsWith(prefix)) {
        return t.substring(prefix.length)
    }
    return null
}
