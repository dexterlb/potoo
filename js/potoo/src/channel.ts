export class Channel<T> {
    private subscribers: Subscriber<T>[]

    public subscribe(callback: Subscriber<T>) {
        this.subscribers.push(callback)
    }

    public send(value: T) {
        this.subscribers.forEach(callback => callback(value))
    }
}

type Subscriber<T> = (value: T) => void
