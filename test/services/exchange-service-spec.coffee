{afterEach, beforeEach, context, describe, it} = global
{expect} = require 'chai'

_ = require 'lodash'
fs = require 'fs'
path = require 'path'
shmock = require 'shmock'
enableDestroy = require 'server-destroy'

base64 = require '../helpers/base64'
Exchange = require '../../src/services/exchange-service'

slurpFile = (filename) => _.trim fs.readFileSync path.join(__dirname, filename), encoding: 'utf8'

CHALLENGE                            = slurpFile '../fixtures/challenge.b64'
NEGOTIATE                            = slurpFile '../fixtures/negotiate.b64'
CREATE_ITEM_RESPONSE                 = slurpFile '../fixtures/createItemResponse.xml'
CREATE_ITEM_ERROR_RESPONSE           = slurpFile '../fixtures/createItemErrorResponse.xml'
DELETE_ITEM_RESPONSE                 = slurpFile '../fixtures/deleteItemResponse.xml'
DELETE_ITEM_ERROR_RESPONSE           = slurpFile '../fixtures/deleteItemErrorResponse.xml'
GET_CALENDAR_RANGE_ERROR_RESPONSE    = slurpFile '../fixtures/getCalendarItemsInRangeErrorResponse.xml'
GET_CALENDAR_RANGE_RESPONSE          = slurpFile '../fixtures/getCalendarItemsInRangeResponse.xml'
GET_CALENDAR_ITEM_ALTERNATE_RESPONSE = slurpFile '../fixtures/getItemCalendarAlternateResponse.xml'
FORWARD_ITEM_RESPONSE                = slurpFile '../fixtures/forwardItemResponse.xml'
FORWARD_ITEM_ERROR_RESPONSE          = slurpFile '../fixtures/forwardItemErrorResponse.xml'
USER_SETTINGS_RESPONSE               = slurpFile '../fixtures/userSettingsResponse.xml'
UPDATE_ITEM_RESPONSE                 = slurpFile '../fixtures/updateItemResponse.xml'
UPDATE_ITEM_ERROR_RESPONSE           = slurpFile '../fixtures/updateItemErrorResponse.xml'
NEGOTIATE_CUSTOM_HOSTNAME            = slurpFile '../fixtures/negotiate-custom-hostname.b64'

describe 'Exchange', ->
  beforeEach ->
    @server = shmock()
    enableDestroy @server

  afterEach (done) ->
    @server.destroy done

  describe 'when the authHostname is inferred', ->
    beforeEach ->
      {port} = @server.address()
      @sut = new Exchange
        protocol: 'http'
        hostname: "localhost"
        port: port
        username: 'foo@biz.biz'
        password: 'bar'

    describe 'authenticate', ->
      describe 'when the server uses Basic Auth', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': 'Basic Realm=""'}

          @server
            .post '/EWS/Exchange.asmx'
            .set 'Authorization', "Basic #{base64 'foo@biz.biz:bar'}"
            .reply 200

          @sut.authenticate (error, @authenticated) => done error

        it 'should yield true', ->
          expect(@authenticated).to.be.true

      describe 'when the credentials are valid', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @server
            .post '/EWS/Exchange.asmx'
            .reply 200

          @sut.authenticate (error, @authenticated) => done error

        it 'should yield true', ->
          expect(@authenticated).to.be.true

      describe 'when the credentials are invalid', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @server
            .post '/EWS/Exchange.asmx'
            .reply 401

          @sut.authenticate (error, @authenticated) => done error

        it 'should yield false', ->
          expect(@authenticated).to.be.false

      describe 'when there is a server error', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @server
            .post '/EWS/Exchange.asmx'
            .reply 500

          @sut.authenticate (@error, @authenticated) => done()

        it 'should yield an error', ->
          expect(@error).to.exist

        it 'should yield no authenticated', ->
          expect(@authenticated).not.to.exist

      describe 'when there is a user error', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @server
            .post '/EWS/Exchange.asmx'
            .reply 429

          @sut.authenticate (@error, @authenticated) => done()

        it 'should yield an error', ->
          expect(@error).to.exist

        it 'should yield no authenticated', ->
          expect(@authenticated).not.to.exist

      describe 'when there is an error during authorization', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 500, '', {'WWW-Authenticate': CHALLENGE}

          @sut.authenticate (@error, @authenticated) => done()

        it 'should yield an error', ->
          expect(@error).to.exist

        it 'should yield no authenticated', ->
          expect(@authenticated).not.to.exist

    describe '->getCalendarItemsInRange', ->
      context 'when the credentials are valid', ->
        beforeEach (done) ->
          @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @getCalendarItemsInRange = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, GET_CALENDAR_RANGE_RESPONSE

          start = '2016-12-28'
          end   = '1999-12-31'
          @sut._getItemsByItemIds = ({itemIds}, callback) => callback null, itemIds
          @sut.getCalendarItemsInRange {start, end}, (@error, @meetings) =>
            done()

        it 'should have 2 meetings', ->
          expect(_.size(@meetings)).to.equal 2

      describe 'when everything is not cool', ->
        beforeEach (done) ->
          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @getCalendarItemsInRange = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, GET_CALENDAR_RANGE_ERROR_RESPONSE

          start = '2016-12-28'
          end   = '1999-12-31'
          @sut.getCalendarItemsInRange {start, end}, (@error) =>
            done()

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should make a get user request to the exchange server', ->
          expect(@getCalendarItemsInRange.isDone).to.be.true

        it 'should yield an error', ->
          expect(@error).to.exist
          expect(@error.code).to.deep.equal 422, @error.message
          expect(@error.message).to.deep.equal 'EndDate is earlier than StartDate'

    describe 'whoami', ->
      describe 'when the credentials are valid', ->
        beforeEach (done) ->
          @negotiate = @server
            .get '/autodiscover/autodiscover.svc'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @getUser = @server
            .post '/autodiscover/autodiscover.svc'
            .reply 200, USER_SETTINGS_RESPONSE

          @sut.whoami (error, @user) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should make a get user request to the exchange server', ->
          expect(@getUser.isDone).to.be.true

        it 'should yield a user', ->
          expect(@user).to.deep.equal {
            name: 'Foo Hampton'
          }

      describe 'when the credentials are invalid', ->
        beforeEach (done) ->
          @negotiate = @server
            .get '/autodiscover/autodiscover.svc'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @getUser = @server
            .post '/autodiscover/autodiscover.svc'
            .reply 401

          @sut.whoami (@error, @user) => done()

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should make a get user request to the exchange server', ->
          expect(@getUser.isDone).to.be.true

        it 'should yield no use', ->
          expect(@user).not.to.exist

        it 'should yield an error with code 401', ->
          expect(@error).to.exist
          expect(@error.code).to.equal 401

    describe 'createItem', ->
      describe 'when creating an item is successful', ->
        beforeEach (done) ->
          options =
            timeZone: 'Star Date Time'
            sendTo: 'SendToWhatever'
            subject: 'Feed the Trolls'
            body: 'A great way to meet and flourish'
            attendees: ['blah@whatever.net', 'imdone@whocares.net', 'null']
            reminder: '2016-09-08T23:00:00-01:00'
            start: '2016-09-09T00:29:00Z'
            end: '2016-09-09T01:00:00Z'
            location: 'Pokémon Go Home'
            extendedProperties:
              something: 'happened'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @createItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, CREATE_ITEM_RESPONSE

          @sut.createItem options, (error, @response) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should make a createItem request to the exchange server', ->
          expect(@createItem.isDone).to.be.true

        it 'should return a calendar event', ->
          expect(@response).to.deep.equal
            itemId: 'AnId'
            changeKey: 'AChangeKey'
            recurrenceId: 'recurrence-id'
            UID: 'the-uid'

      describe 'when creating an item returns an error', ->
        beforeEach (done) ->
          options =
            timeZone: 'Star Date Time'
            sendTo: 'SendToWhatever'
            subject: 'Feed the Trolls'
            body: 'A great way to meet and flourish'
            attendees: ['blah@whatever.net', 'imdone@whocares.net']
            reminder: '2016-09-08T23:00:00-01:00'
            start: '2016-09-09T00:29:00Z'
            end: '1999-09-09T01:00:00Z'
            location: 'Pokémon Go Home'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @createItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, CREATE_ITEM_ERROR_RESPONSE

          @sut.createItem options, (@error, @response) => done()

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should return a 422 error', ->
          expect(@error).to.exist
          expect(@error.code).to.equal 422
          expect(@error.message).to.equal 'Unprocessable Entity: EndDate is earlier than StartDate'

    describe 'deleteItem', ->
      describe 'when deleting an item is successful', ->
        beforeEach (done) ->
          options =
            itemId:    'deleteItemId'
            changeKey: 'deleteItemChangeKey'
            recurrenceId: 'recurrence-id'
            UID: 'the-uid'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @deleteItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, DELETE_ITEM_RESPONSE

          @sut.deleteItem options, (error, @response) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should call deleteItem', ->
          expect(@deleteItem.isDone).to.be.true

        it 'should return a calendar event', ->
          expect(@response).to.deep.equal
            itemId: 'deleteItemId'
            changeKey: 'deleteItemChangeKeyNew'
            recurrenceId: 'recurrence-id'
            UID: 'the-uid'

      describe 'when deleting an item returns an error', ->
        beforeEach (done) ->
          options =
            itemId:    'deleteItemId'
            changeKey: 'malformed'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @createItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, DELETE_ITEM_ERROR_RESPONSE

          @sut.createItem options, (@error, @response) => done()

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should return a 422 error', ->
          expect(@error).to.exist
          expect(@error.code).to.equal 422
          expect(@error.message).to.equal 'Unprocessable Entity: The change key is invalid.'

    describe 'getItem', ->
      beforeEach (done) ->
        @server
          .get '/EWS/Exchange.asmx'
          .set 'Authorization', NEGOTIATE
          .reply 401, '', {'WWW-Authenticate': CHALLENGE}

        @server
          .post '/EWS/Exchange.asmx'
          .reply 200, GET_CALENDAR_ITEM_ALTERNATE_RESPONSE

        @sut.getItemByItemId 'item-id', (error, @item) => done error

      it 'should parse the item', ->
        expect(@item.urls.clothing.has.aaron).to.contain {url: 'https://aaron.has.clothing/meet/123456'}

    describe 'updateItem', ->
      describe 'when creating an item is successful', ->
        beforeEach (done) ->
          options =
            itemId: 'AnId'
            changeKey: 'AChangeKey'
            subject: 'Feed the Trolls'
            attendees: ['no@sleep.net', 'til@brooklyn.net']
            start: '2016-09-10T00:29:00Z'
            end: '2016-09-10T01:00:00Z'
            location: 'Mexico?'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @updateItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, UPDATE_ITEM_RESPONSE

          @sut.updateItem options, (error, @response) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should return a calendar event', ->
          expect(@response).to.deep.equal
            itemId: 'AnId'
            changeKey: 'AChangeKey'
            recurrenceId: 'recurrence-id'
            UID: 'the-uid'

      describe 'when creating an item fails', ->
        beforeEach (done) ->
          options =
            itemId: 'AnId'
            changeKey: 'wrong-wrong'
            subject: 'Feed the Trolls'
            attendees: ['no@sleep.net', 'til@brooklyn.net']
            start: '2016-09-10T00:29:00Z'
            end: '2016-09-10T01:00:00Z'
            location: 'Mexico?'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @updateItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, UPDATE_ITEM_ERROR_RESPONSE

          @sut.updateItem options, (@error, @item) => done()

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should return a 422 error', ->
          expect(@error).to.exist
          expect(@error.code).to.equal 422
          expect(@error.message).to.equal 'Unprocessable Entity: The change key is invalid.'

  describe 'when the authHostname is given', ->
    beforeEach ->
      {port} = @server.address()
      @sut = new Exchange
        protocol: 'http'
        hostname: "localhost"
        port: port
        username: 'foo@biz.biz'
        password: 'bar'
        authHostname: 'biz.bikes'

    describe 'when the credentials are valid', ->
      beforeEach (done) ->
        @negotiate = @server
          .get '/autodiscover/autodiscover.svc'
          .set 'Authorization', NEGOTIATE_CUSTOM_HOSTNAME
          .reply 401, '', {'WWW-Authenticate': CHALLENGE}

        @getUser = @server
          .post '/autodiscover/autodiscover.svc'
          .reply 201

        @sut.whoami done

      it 'should make a negotiate request to the exchange server with the given authHostname', ->
        expect(@negotiate.isDone).to.be.true

    describe 'forwardItem', ->
      describe 'when creating an item is successful', ->
        beforeEach (done) ->
          options =
            email: 'newguy@whatevs.co'
            itemId: 'some-item-id'
            changeKey: 'some-change-key'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @forwardItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, FORWARD_ITEM_RESPONSE

          @sut.forwardItem options, (error, @response) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should make a forwardItem request to the exchange server', ->
          expect(@forwardItem.isDone).to.be.true

        it 'should return an empty object', ->
          expect(@response).to.deep.equal {}

      describe 'when creating an item fails', ->
        beforeEach (done) ->
          options =
            itemId: 'AnId'
            changeKey: 'wrong-wrong'
            email: 'i@broke.it'

          @negotiate = @server
            .get '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @updateItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 200, FORWARD_ITEM_ERROR_RESPONSE

          @sut.forwardItem options, (@error, @item) => done()

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should return a 422 error', ->
          expect(@error).to.exist
          expect(@error.code).to.equal 422
          expect(@error.message).to.equal 'Unprocessable Entity: The change key is invalid.'
