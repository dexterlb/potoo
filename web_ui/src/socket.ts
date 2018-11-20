export class Sockets {
    private sockets: { [key: string]: Socket }
    private _received: ((key: string, data: any) => void);
    private _connected: ((key: string) => void);
    private _disconnected: ((key: string, reason: any) => void);

    constructor() {
        this.sockets = {};
    }

    connect(key: string, url: string) {
        if (!(key in this.sockets)) {
            this.sockets[key] = new Socket();
            this.sockets[key].received((data) => {
                this._received(key, data);
            });
            this.sockets[key].connected(() => {
                this._connected(key);
            });
            this.sockets[key].disconnected((reason) => {
                this._disconnected(key, reason);
            });
        }

        this.sockets[key].connect(url);
    }

    send(key: string, data: any) {
        if (!(key in this.sockets)) {
            return;
        }

        this.sockets[key].send(data);
    }

    received(f: ((data: any) => void)) {
        this._received = f;
    }

    connected(f: ((key: string) => void)) {
        this._connected = f;
    }

    disconnected(f: ((key: string, reason: string) => void)) {
        this._disconnected = f;
    }
}

export class Socket {
    private ws: WebSocket | null;
    private _received:      ((data: any)        => void);
    private _connected:     (()                 => void);
    private _disconnected:  ((reason: string)   => void);

    constructor() {
        this.ws = null;
    }

    connect(url: string) {
        console.log("want to connect to", url);
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }

        var ws = new WebSocket(url);
        ws.addEventListener('open', (event: object) => {
            if (this.ws == ws) {
                this._connected();
            }
        });
        ws.addEventListener('message', (event: { data: string }) => {
            if (this.ws == ws) {
                this._received(JSON.parse(event.data));
            }
        });
        ws.addEventListener('close', (event: object) => {
            if (this.ws == ws) {
                this._disconnected('closed');
                this.ws = null;
            }
        });

        this.ws = ws;
    }

    send(data: any) {
        if (!this.ws) {
            console.log("want to send data to closed socket: ", data);
            return;
        }

        this.ws.send(JSON.stringify(data));
    }

    received(f: ((data: any) => void)) {
        this._received = f;
    }

    connected(f: (() => void)) {
        this._connected = f;
    }

    disconnected(f: ((reason: string) => void)) {
        this._disconnected = f;
    }
}
