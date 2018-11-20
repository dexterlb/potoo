export class Sockets {
    private sockets: { [key: string]: Socket }
    private _received: ((key: string, data: any) => void);
    private _connected: ((key: string, data: any) => void);
    private _disconnected: ((key: string, data: any) => void);

    constructor() {
        this.sockets = {};
    }

    connect(key: string, url: string) {
        if (!(key in this.sockets)) {
            this.sockets[key] = new Socket();
            this.sockets[key].received(function(data) {
                this._received(key, data);
            });
            this.sockets[key].connected(function() {
                this._connected(key);
            });
            this.sockets[key].disconnected(function(reason) {
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

    received(key: string, f: ((key: string, data: any) => void)) {
        this._received = f;
    }

    connected(key: string, f: ((key: string) => void)) {
        this._connected = f;
    }

    disconnected(key: string, f: ((key: string, reason: string) => void)) {
        this._disconnected = f;
    }
}

export class Socket {
    connect(url: string) {
        console.log("want to connect to", url);
    }

    send(data: any) {

    }

    received(f: ((data: any) => void)) {

    }

    connected(f: (() => void)) {

    }

    disconnected(f: ((reason: string) => void)) {

    }
}
