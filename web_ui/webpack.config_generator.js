const   path                          = require('path');
const   HtmlWebpackPlugin             = require('html-webpack-plugin');
const   HtmlWebpackInlineSourcePlugin = require('html-webpack-inline-source-plugin');
const   WebpackShellPluginNext        = require('webpack-shell-plugin-next');
const   fs                            = require('fs');


function base64_encode(file) {
    var bitmap = fs.readFileSync(file);
    return new Buffer(bitmap).toString('base64');
}

function build_config(mode) {
    if (mode == 'prod') {
      var elm_loader_options = {
        verbose: true,
        optimize: true
      };
      var extra_options = {
        mode: 'production',
        performance: {
          hints: false
        }
      };
    } else if (mode == 'dev') {
      var elm_loader_options = {
        verbose: true,
      };
      var extra_options = {
        mode: 'development',

        performance: {
          hints: false
        },

        devtool: 'inline-source-map',

        devServer: {
          host: '::',
          port: 8081,
          liveReload: false,
          hot: false,
          webSocketServer: false,
          proxy: {
            '/ws': {
              target: 'ws://localhost:1880',
              ws: true
            }
          },
          allowedHosts: 'all',
        },
      };
    } else {
      throw new Error('unknown mode: ' + mode)
    }

    var css_loader_chain = [
      { loader: 'style-loader' },
      { loader: 'css-loader' },
    ]

    var sass_loader_chain = [
      ...css_loader_chain,
      { loader: 'sass-loader' },
    ]

    var excludes = [/elm-stuff/]

    return Object.assign({
      context: path.resolve (__dirname, 'src'),
      entry: {
        app: [
          './index.ts'
        ]
      },

      output: {
        path: path.resolve(__dirname + '/dist'),
        publicPath: '',
        filename: '[name].js',
      },

      plugins: [
        new WebpackShellPluginNext({
          onBuildStart:{
            scripts: ['bash scripts/pre_build.sh'],
            blocking: true,
            parallel: false
          },
          onBuildEnd:{
            scripts: ['bash scripts/post_build.sh'],
            blocking: true,
            parallel: false
          },
        }),
        new HtmlWebpackPlugin({
          inlineSource: '.js$',
          template: 'index.ejs',
          templateParameters: (compilation, assets, assetTags, options) => {
            return {
              compilation,
              webpackConfig: compilation.options,
              htmlWebpackPlugin: {
                tags: assetTags,
                files: assets,
                options
              },
              'favicon': 'data:image/png;base64,' + base64_encode('./src/images/favicon.png'),
            };
          },
        }),
        new HtmlWebpackInlineSourcePlugin(),
      ],

      module: {
        rules: [
          {
            test: /\.(scss)$/,
            use: sass_loader_chain,
          },
          {
            test: /\.(css)$/,
            use: css_loader_chain,
          },
          {
            test: /\.tsx?$/,
            use: 'ts-loader',
            exclude: excludes,
          },
          {
            test:    /\.elm$/,
            exclude: excludes,
            loader:  'elm-webpack-loader',
            options: elm_loader_options,
          },
          {
            test: /\.(woff|woff2|png|ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/,
            exclude: excludes,
            type: 'asset/inline',
            parser: {
              dataUrlCondition: (source, { filename, module }) => {
                return true;  // inline everything!
              },
            }
          },
        ],

        noParse: /\.elm$/,
      },
    }, extra_options);
}

module.exports = build_config;
