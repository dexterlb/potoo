export class Channel<T> {
    private subscribers: Subscriber<T>[]

    public subscribe(callback: Subscriber<T>) {
        this.subscribers.push(callback)
    }

    public send(value: T) {
        if (this.subscribers.length == 0) {
            console.log('the message ', value, ' is sent in an empty forest with nobody around. ',
                'Did it even exist?')
        }
        this.subscribers.forEach(callback => callback(value))
    }
}

type Subscriber<T> = (value: T) => void
