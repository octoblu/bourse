_          = require 'lodash'
moment     = require 'moment'
stream     = require 'stream'
xmlNodes   = require 'xml-nodes'
xmlObjects = require 'xml-objects'
xml2js     = require 'xml2js'

debug = require('debug')('bourse:exchange-stream')
AuthenticatedRequest = require '../services/authenticated-request'

XML_OPTIONS = {
  tagNameProcessors: [xml2js.processors.stripPrefix]
  explicitArray: false
}

CONNECTION_STATUS_PATH = 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages.GetStreamingEventsResponseMessage.ConnectionStatus'

class ExchangeStream extends stream.Readable
  constructor: ({connectionOptions, @request, timeout}) ->
    super objectMode: true

    throw new Error 'missing required parameter: request' unless @request

    timeout ?= 60 * 1000

    {protocol, hostname, port, username, password} = connectionOptions
    @authenticatedRequest = new AuthenticatedRequest {protocol, hostname, port, username, password}

    debug 'connecting...'
    @request
      .pipe(xmlNodes('Envelope'))
      .pipe(xmlObjects(XML_OPTIONS))
      .on 'data', @_onData

    @request.once 'error', @_onError

    @_pushBackTimeout = _.debounce @_onTimeout, timeout
    @_pushBackTimeout()

    @request
      .pipe(xmlNodes('Envelope'))
      .on 'data', (data) => debug data.toString()

  destroy: =>
    debug 'destroy'
    @_pushBackTimeout.cancel()
    @request.abort?()
    @request.socket?.destroy?()
    @_isClosed = true
    @push null

  _onData: (data) =>
    debug '_onData'

    return @destroy() if 'Closed' == _.get data, CONNECTION_STATUS_PATH
    @_pushBackTimeout()

    return if _.isEmpty _.get(data, 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages')
    @push {timestamp: moment.utc().format()}

  _onError: (error) =>
    console.error error.stack
    @destroy()

  _onTimeout: =>
    @destroy()

  _read: =>

module.exports = ExchangeStream
