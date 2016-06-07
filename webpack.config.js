var path = require('path');
var webpack = require('webpack');

var env = process.env.NODE_ENV;

var config = {
    entry: [
        './src/oms.coffee'
    ],
    plugins: [
        new webpack.optimize.OccurenceOrderPlugin(),
        new webpack.DefinePlugin({
            'process.env.NODE_ENV': JSON.stringify(env)
        })
    ],
    output: {
        path:          path.join(__dirname, 'dist'),
        publicPath:    '/dist/',
        filename:      'oms.js',
        library:       'OverlappingMarkerSpiderfier',
        libraryTarget: 'umd',
    },
    module: {
        loaders: [
            {
                test: /\.coffee$/,
                loader: 'coffee',
                exclude: /node_modules/,
                include: __dirname,
            }
        ]
    }
};

if (env === 'production') {
    config.plugins.push(
        new webpack.optimize.UglifyJsPlugin({
            compressor: {
                pure_getters: true,
                screw_ie8: true,
                warnings: false,
            }
        })
    );

    config.output.filename = 'oms.min.js';
} else {
    config.plugins.push(
        new webpack.HotModuleReplacementPlugin()
    );

    config.entry.unshift(
        'webpack-dev-server/client?http://localhost:3000',
        'webpack/hot/dev-server'
    );
}

module.exports = config;
