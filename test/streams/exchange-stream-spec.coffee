{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'

fs            = require 'fs'
_             = require 'lodash'
moment        = require 'moment'
path          = require 'path'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
sinon         = require 'sinon'
{PassThrough} = require 'stream'

ExchangeStream = require '../../src/streams/exchange-stream'

CALENDAR_EVENT = fs.readFileSync path.join(__dirname, '../fixtures/calendarEvent.xml')
CALENDAR_EVENT2 = fs.readFileSync path.join(__dirname, '../fixtures/calendarEvent2.xml')
CLOSED_EVENT = fs.readFileSync path.join(__dirname, '../fixtures/closedEvent.xml')
GET_ITEM_CALENDAR_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/getItemCalendarResponse.xml')
CHALLENGE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/challenge.b64'), encoding: 'utf8'
NEGOTIATE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate.b64'), encoding: 'utf8'

describe 'ExchangeStream', ->
  beforeEach ->
    @clock = sinon.useFakeTimers(moment('2016-11-19T12:00:00Z').valueOf())

    @server = shmock()
    enableDestroy @server
    {port} = @server.address()

    @request = new PassThrough objectMode: true
    @sut = new ExchangeStream {
      request: @request
      timeout: 200
      connectionOptions:
        protocol: 'http'
        hostname: 'localhost'
        port: port
        username: 'foo@biz.biz'
        password: 'bar'
    }

  afterEach (done) ->
    @sut.destroy()
    @server.destroy done
    @clock.restore()

  describe 'when the request emits a calendar event', ->
    beforeEach (done) ->
      @sut.on 'readable', _.once(done)
      @server
        .get '/EWS/Exchange.asmx'
        .set 'Authorization', NEGOTIATE
        .reply 401, '', {'WWW-Authenticate': CHALLENGE}

      @getUser = @server
        .post '/EWS/Exchange.asmx'
        .reply 200, GET_ITEM_CALENDAR_RESPONSE

      @request.write CALENDAR_EVENT

    it 'should have a calendar event readable', ->
      event = @sut.read()
      expect(event).to.deep.equal {
        timestamp: '2016-11-19T12:00:00Z'
      }

  describe 'when the request emits another calendar event', ->
    beforeEach (done) ->
      @sut.on 'readable', _.once(done)
      @server
        .get '/EWS/Exchange.asmx'
        .set 'Authorization', NEGOTIATE
        .reply 401, '', {'WWW-Authenticate': CHALLENGE}

      @getUser = @server
        .post '/EWS/Exchange.asmx'
        .reply 200, GET_ITEM_CALENDAR_RESPONSE

      @request.write CALENDAR_EVENT2

    it 'should have a calendar event readable', ->
      event = @sut.read()
      expect(event).to.deep.equal {
        timestamp: '2016-11-19T12:00:00Z'
      }

  describe 'when the request emits a closed event', ->
    beforeEach (done) ->
      @timeout 100
      @sut.on 'end', done
      @sut.on 'readable', => @sut.read()

      @request.write CLOSED_EVENT

    it 'should close the stream', ->
      # Getting here is good enough

  describe 'when the request times out', ->
    beforeEach (done) ->
      @clock.tick 300
      @sut.on 'end', done
      @sut.on 'readable', => @sut.read() # end will not emit until stream is fully read

    it 'should close the stream', ->
      # Getting here is not good enough
