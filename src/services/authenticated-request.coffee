_            = require 'lodash'
{ntlm}       = require 'httpntlm'
request      = require 'request'
https        = require 'https'
http         = require 'http'
url          = require 'url'
xml2js       = require 'xml2js'
debug        = require('debug')('bourse:authenticated-request')
debugSecrets = require('debug')('secret:bourse:authenticated-request')

EWS_PATH = '/EWS/Exchange.asmx'
AUTODISCOVER_PATH = '/autodiscover/autodiscover.svc'

class AuthenticatedRequest
  constructor: ({@protocol, @hostname, @port, @username, @password, @authHostname}) ->
    throw new Error 'Missing required parameter: hostname' unless @hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    @protocol ?= 'https'
    @port ?= 443

  do: ({pathname, body}, callback) =>
    transactionId = _.random 0, 1000
    debugSecrets 'credentials', transactionId, JSON.stringify({@username})
    @_getRequest {pathname}, (error, request) =>
      return callback error if error?

      debug 'request', transactionId, body
      request.post {body}, (error, response) =>
        extra = _.pick response, 'statusCode', 'headers'
        return callback error, null, extra if error?

        debug 'response', transactionId, response.body, extra
        @_xml2js response.body, (error, obj) =>
          return callback error, null, extra if error?
          return callback null, obj, extra

  doAutodiscover: ({body}, callback) =>
    @do {body, pathname: AUTODISCOVER_PATH}, callback

  doEws: ({body}, callback) =>
    @do {body, pathname: EWS_PATH}, callback

  getOpenEwsRequest: ({body}, callback) =>
    @_getRequest pathname: EWS_PATH, (error, authenticatedRequest) =>
      return callback error if error?
      return callback null, authenticatedRequest.post({body})

  _getRequest: ({pathname}, callback) =>
    urlStr = url.format { @protocol, @hostname, @port, pathname }
    username = _.first _.split @username, '@'
    ntlmOptions =
      url: urlStr
      username: username
      password: @password
      workstation: ''
      domain: ''

    if @protocol == 'https'
      keepaliveAgent = new https.Agent({keepAlive: true});
    else
      keepaliveAgent = new http.Agent({keepAlive: true});

    options =
      url: urlStr
      agent: keepaliveAgent
      headers:
        'Content-Type': 'text/xml; charset=utf-8'
        'Authorization': ntlm.createType1Message(ntlmOptions)

    request.get options, (error, response) =>
      return callback error if error?
      unless response.statusCode == 401
        return callback new Error("Expected status: 401, received #{response.statusCode}")

      type2msg = ntlm.parseType2Message response.headers['www-authenticate']
      type3msg = ntlm.createType3Message type2msg, ntlmOptions

      options =
        url: urlStr
        agent: keepaliveAgent
        headers:
          'Authorization': type3msg
          'Content-Type': 'text/xml; charset=utf-8'

      callback null, request.defaults(options)

  _xml2js: (xml, callback) =>
    options = {
      tagNameProcessors: [xml2js.processors.stripPrefix]
      explicitArray: false
    }
    xml2js.parseString xml, options, callback

module.exports = AuthenticatedRequest
