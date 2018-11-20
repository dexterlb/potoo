require('./index.html');
require('./styles/main.scss');

let socket = require('./socket.ts')
let elm = require('./Main.elm');

let app = elm.Elm.Main.init({ node: document.documentElement });

var sockets = new socket.Sockets();

sockets.received((key: string, data: any) => {
    app.ports.incoming.send({'key': key, 'data': data});
});

sockets.connected((key: string) => {
    app.ports.incoming.send({'key': key, 'status': 'connected'});
});

sockets.disconnected((key: string, reason: string) => {
    console.log("disconnected because of", reason);
    app.ports.incoming.send({'key': key, 'status': 'disconnected'});
});

app.ports.outgoing.subscribe((msg: any) => {
    if (msg.action == 'connect') {
        sockets.connect(msg.key, msg.url);
    } else if (msg.action == 'send') {
        sockets.send(msg.key, msg.data);
    } else {
        console.log('unable to handle port message', msg);
    }
});
