export class Channel<T> {
    private subscribers: Subscriber<T>[] = []

    constructor(private value: T, private options?: ChannelOptions) {}

    public async subscribe(callback: Subscriber<T>): Promise<void> {
        if (this.options) {
            if (this.subscribers.length == 0) {
                await this.options.on_first_subscribed()
            }
            await this.options.on_subscribed()
        }
        this.subscribers.push(callback)
    }

    public async unsubscribe(callback: Subscriber<T>): Promise<void> {
        this.subscribers.filter(other => !Object.is(other, callback))
        if (this.options) {
            if (this.subscribers.length == 0) {
                await this.options.on_last_unsubscribed()
            }
            await this.options.on_unsubscribed()
        }
    }

    public send(value: T) {
        this.value = value
        if (this.subscribers.length == 0) {
            console.log('the message ', value, ' is sent in an empty forest with nobody around. ',
                'Did it even exist?')
        }
        this.subscribers.forEach(callback => callback(value))
    }

    public get(): T {
        return this.value
    }
}

type Subscriber<T> = (value: T) => void

interface ChannelOptions {
    on_first_subscribed: () => Promise<void>,
    on_last_unsubscribed: () => Promise<void>,
    on_subscribed: () => Promise<void>,
    on_unsubscribed: () => Promise<void>,
}
