/**
 * A generic module for working with MQTT
 */

/**
 * MQTT topics are UTF-8 strings which may contain topic elements delimited
 * by forward slashes.
 *
 * A topic element may be:
 *
 * - A `+` wildcard, which matches an arbitrary element
 * - A `#` wildcard, which matches any number of arbitrary elemsnts
 * - Any UTF-8 string, which matches itself
 */
export type Topic = string

/**
 * MQTT Client interface.
 */
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

/**
 * Like [[join_topics]] but for any number of topics.
 * Acts like [[trim_topic]] when given a single topic.
 */
export function join_topic_list(topics: Array<Topic>): Topic {
    return topics.reduce(join_topics, '')
}

/**
 * Concatenate two topics, making sure there are no leading or trailing slashes
 */
export function join_topics(a: Topic, b: Topic): Topic {
    a = trim_topic(a)
    b = trim_topic(b)
    if (a == '') return b;
    if (b == '') return a;
    return a + '/' + b
}

/**
 * Remove any leading or trailing slashes
 */
export function trim_topic(t: Topic): Topic {
    return t.replace(/^\/+|\/+$/g, '')
}

/**
 * Strip a prefix path from a topic
 * @param prefix The path which will be removed from the start of `t`
 * @param t A topic
 * @return If `t` starts with `prefix`, returns `t` without `prefix`. Otherwise,
 *         returns `null`.
 */
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
