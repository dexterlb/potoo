export class Bus<T> {
    private subscribers: Subscriber<T>[] = []
    private transient_subscribers: Subscriber<T>[] = []

    private value: T | undefined

    constructor(private options?: BusOptions) {}

    public async subscribe(callback: Subscriber<T>): Promise<void> {
        let action = this.check_subscribe()
        this.subscribers.push(callback)
        await action()
    }

    public async unsubscribe(callback: Subscriber<T>): Promise<void> {
        this.subscribers.filter(other => !Object.is(other, callback))
        await this.check_unsubscribe()()
    }

    public send(value: T) : Bus<T> {
        this.value = value
        this.subscribers.forEach(callback => callback(value))
        if (this.transient_subscribers.length > 0) {
            this.transient_subscribers.forEach(callback => callback(value))
            this.transient_subscribers = []
            this.check_unsubscribe()()
        }
        return this
    }

    public async get(timeout: number = 5000): Promise<T> {
        if (this.value != undefined) {
            return Promise.resolve(this.value)
        }
        return new Promise((resolve, reject) => {
            let action = this.check_subscribe()
            this.transient_subscribers.push(resolve)
            setTimeout(() => reject('timeout'), timeout)
            action().then(() => {}).catch(reject)
        })
    }

    private check_subscribe(): () => Promise<void> {
        let side_effects: Array<Promise<void>> = []
        if (this.options) {
            if (this.subscribers.length + this.transient_subscribers.length == 0) {
                side_effects.push(this.options.on_first_subscribed())
            }
            side_effects.push(this.options.on_subscribed())
        }
        return async () => { await Promise.all(side_effects) }
    }

    private check_unsubscribe(): () => Promise<void> {
        let side_effects: Array<Promise<void>> = []
        if (this.options) {
            if (this.subscribers.length + this.transient_subscribers.length == 0) {
                side_effects.push(this.options.on_last_unsubscribed())
            }
            side_effects.push(this.options.on_unsubscribed())
        }
        return async () => { await Promise.all(side_effects) }
    }
}

type Subscriber<T> = (value: T) => void

interface BusOptions {
    on_first_subscribed: () => Promise<void>,
    on_last_unsubscribed: () => Promise<void>,
    on_subscribed: () => Promise<void>,
    on_unsubscribed: () => Promise<void>,
}
