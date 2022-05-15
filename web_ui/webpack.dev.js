const { merge } = require('webpack-merge');
const path      = require('path');
const common    = require('./webpack.common.js');

module.exports = merge(common, {
  mode: 'development',

  devtool: 'inline-source-map',

  devServer: {
    host: '0.0.0.0',
    port: '8082',
    hot: false,
    liveReload: false,
    webSocketServer: false,
    proxy: {
      '/ws': {
        target: 'ws://localhost:1880',
        ws: true
      }
    },
    allowedHosts: 'all',
  },
});
