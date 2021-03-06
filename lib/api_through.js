(function() {
  var ApiThrough, PassThrough;

  module.exports = function() {
    return new ApiThrough();
  };

  PassThrough = require('stream').PassThrough;

  ApiThrough = (function() {
    var Proxy, SSLCert, fs;

    Proxy = require('http-mitm-proxy');

    SSLCert = require('./ssl_cert');

    fs = require('fs');

    function ApiThrough() {
      var host, mongooose;
      mongooose = require('mongoose');
      host = process.env["MONGODB_PORT_27017_TCP_ADDR"] || 'localhost';
      console.log("Connecting to mongo at " + host);
      mongooose.connect("mongodb://" + host + ":27017/apis");
    }

    ApiThrough.prototype.start = function() {
      var proxy;
      proxy = new Proxy();
      proxy.use(this);
      proxy.onCertificateMissing = (function(_this) {
        return function(ctx, files, callback) {
          return _this.onCertificateMissing(ctx, files, callback);
        };
      })(this);
      proxy.listen({
        port: process.env['PROXY_PORT'] || 9081,
        sslCertCacheDir: './scripts/certs/http-mitm-proxy'
      });
      return this.proxy = proxy;
    };

    ApiThrough.prototype.onCertificateMissing = function(ctx, files, callback) {
      var sslCert;
      console.log('Looking for "%s" certificates', ctx.hostname);
      console.log('"%s" missing', ctx.files.keyFile);
      console.log('"%s" missing', ctx.files.certFile);
      sslCert = new SSLCert(ctx.hostname);
      return sslCert.create((function(_this) {
        return function() {
          return callback(null, {
            keyFileData: fs.readFileSync(ctx.files.keyFile),
            certFileData: fs.readFileSync(ctx.files.certFile)
          });
        };
      })(this));
    };

    ApiThrough.prototype.onError = function(ctx, err) {
      console.error('proxy error:', err);
      return console.error('proxy error stack:', err.stack);
    };

    ApiThrough.prototype.onRequest = function(ctx, callback) {
      var ApiExample, User, apiExample, responseAggregator, responseBody;
      ApiExample = require('./api_example');
      User = require('./user');
      ctx.onError((function(_this) {
        return function(ctx, err) {
          return _this.onError(ctx, err);
        };
      })(this));
      apiExample = new ApiExample();
      apiExample.populateFromRequest(ctx.clientToProxyRequest);
      apiExample.setFullUrl(ctx.isSSL, ctx.proxyToServerRequestOptions);
      responseBody = '';
      responseAggregator = new PassThrough();
      responseAggregator.on('finish', function() {
        apiExample.responseBody = responseBody;
        apiExample.stripResponseBody();
        return User.findOne({
          api_token: apiExample.apiToken
        }, function(err, user) {
          var apiExampleRaw;
          console.log('findOne', err, user);
          if (user) {
            apiExample.userId = user.id;
          }
          apiExampleRaw = apiExample.toObject();
          delete apiExampleRaw._id;
          return ApiExample.findOneAndUpdate({
            digest: apiExample.digest
          }, apiExampleRaw, {
            upsert: true
          }, function(error) {
            if (error != null) {
              return console.log("Failed to save due to error", error);
            }
          });
        });
      });
      ctx.addResponseFilter(responseAggregator);
      ctx.onRequestData(function(ctx, chunk, callback) {
        apiExample.requestBody += chunk.toString('utf8');
        return callback(null, chunk);
      });
      ctx.onResponse(function(ctx, callback) {
        apiExample.responseHeaders = ctx.serverToProxyResponse.headers;
        apiExample.statusCode = ctx.serverToProxyResponse.statusCode;
        ctx.serverToProxyResponse.on("finish", function() {
          return console.log("FINISH");
        });
        return callback();
      });
      ctx.onResponseData(function(ctx, chunk, callback) {
        responseBody += chunk.toString('utf8');
        return callback(null, chunk);
      });
      return callback();
    };

    return ApiThrough;

  })();

}).call(this);
