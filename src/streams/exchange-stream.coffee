_          = require 'lodash'
moment     = require 'moment'
stream     = require 'stream'
xmlNodes   = require 'xml-nodes'
xmlObjects = require 'xml-objects'
xml2js     = require 'xml2js'

debug = require('debug')('bourse:exchange-stream')

XML_OPTIONS = {
  tagNameProcessors: [xml2js.processors.stripPrefix]
  explicitArray: false
}

RESPONSE_MESSAGE_PATH = 'Envelope.Body.GetStreamingEventsResponse.ResponseMessages.GetStreamingEventsResponseMessage'
CONNECTION_STATUS_PATH = "#{RESPONSE_MESSAGE_PATH}.ConnectionStatus"
NOTIFICATIONS_PATH = "#{RESPONSE_MESSAGE_PATH}.Notifications"

class ExchangeStream extends stream.Readable
  constructor: ({connectionOptions, @request}) ->
    super objectMode: true

    throw new Error 'missing required parameter: request' unless @request

    {protocol, hostname, port, username, password} = connectionOptions

    debug 'connecting...'
    @request
      .pipe(xmlNodes('Envelope'))
      .pipe(xmlObjects(XML_OPTIONS))
      .on 'data', @_onData

    @request.on 'error', @_onError

    @request
      .pipe(xmlNodes('Envelope'))
      .on 'data', (data) => debug data.toString()

  destroy: =>
    debug 'destroy'
    return if @_isClosed
    @request.abort?()
    @request.socket?.destroy?()
    @_isClosed = true
    @push null

  _onData: (data) =>
    debug '_onData', JSON.stringify(data,null,2)
    return @destroy() if 'Closed' == _.get data, CONNECTION_STATUS_PATH
    return if _.isEmpty _.get(data, NOTIFICATIONS_PATH)
    @push {timestamp: moment.utc().format()}

  _onError: (error) =>
    console.error "bourse:exchange-stream error", error.stack
    @destroy()

  _read: =>

module.exports = ExchangeStream
