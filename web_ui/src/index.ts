require('./index.html');
require('./styles/main.scss');

var elm = require('./Main.elm');

var app = elm.Elm.Main.init({ node: document.documentElement });

app.ports.outgoing.subscribe(function(msg: any) {
    console.log("msg: ", msg);
});
