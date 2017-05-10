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
  constructor: ({@protocol, @hostname, @port, @username, @password, @authHostname, @timeout}) ->
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
    throw new Error 'callback must be a function' unless _.isFunction callback

    urlStr = url.format { @protocol, @hostname, @port, pathname }

    keepaliveAgent = new https.Agent keepAlive: true
    keepaliveAgent = new http.Agent keepAlive: true if @protocol == 'http'

    options =
      url: urlStr
      agent: keepaliveAgent
      timeout: @timeout
      headers:
        'Content-Type': 'text/xml; charset=utf-8'
        'Authorization': ntlm.createType1Message @_ntlmOptions(urlStr)

    request.get options, (error, response) =>
      return callback error if error?
      unless response.statusCode == 401
        return callback new Error("Expected status: 401, received #{response.statusCode}")

      authenticateHeader   = response.headers['www-authenticate']
      authenticationMethod = @_parseAuthenticationMethod authenticateHeader

      return @_buildNtlmRequest {keepaliveAgent, authenticateHeader, urlStr}, callback if authenticationMethod == 'ntlm'
      return @_buildBasicRequest {urlStr}, callback if authenticationMethod == 'basic'
      return callback new Error "Unsupported authenticationMethod: #{authenticationMethod}"

  _buildBasicRequest: ({urlStr}, callback) =>
    options =
      url: urlStr
      auth: { @username, @password }
      headers:
        'Content-Type': 'text/xml; charset=utf-8'
        
    callback null, request.defaults(options)

  _buildNtlmRequest: ({keepaliveAgent, authenticateHeader, urlStr}, callback) =>
    type2msg = ntlm.parseType2Message authenticateHeader
    type3msg = ntlm.createType3Message type2msg, @_ntlmOptions(urlStr)

    options =
      url: urlStr
      agent: keepaliveAgent
      headers:
        'Authorization': type3msg
        'Content-Type': 'text/xml; charset=utf-8'

    callback null, request.defaults(options)

  _ntlmOptions: (urlStr) =>
    return {
      url: urlStr
      username: _.first _.split(@username, '@')
      password: @password
      workstation: ''
      domain: ''
    }

  _parseAuthenticationMethod: (authenticateHeader) =>
    _.toLower _.first _.split(authenticateHeader, ' ')

  _xml2js: (xml, callback) =>
    options = {
      tagNameProcessors: [xml2js.processors.stripPrefix]
      explicitArray: false
    }
    xml2js.parseString xml, options, callback

module.exports = AuthenticatedRequest
