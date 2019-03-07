export class Channel<T> {
    private subscribers: Subscriber<T>[]

    constructor(private value: T) {}

    public subscribe(callback: Subscriber<T>) {
        this.subscribers.push(callback)
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
