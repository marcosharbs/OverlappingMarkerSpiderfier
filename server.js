var webpack = require('webpack');
var webpackDevServer = require('webpack-dev-server');
var config = require('./webpack.config');

var port = 3000;

var compiler = webpack(config);
var server = new webpackDevServer(compiler, {
    hot: true,
    quiet: true,
    publicPath: config.output.publicPath,
});

server.listen(port, function(error) {
    if (error) {
        console.error(error);
    } else {
        console.info('==> Listening on port %s. Open up http://localhost:%s/examples/ in your browser.', port, port);
    }
});
