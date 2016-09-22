{afterEach, beforeEach, describe, it, contain} = global
_ = require 'lodash'
fs = require 'fs'
path = require 'path'
shmock = require 'shmock'
enableDestroy = require 'server-destroy'

Exchange = require '../../src/services/exchange-service'
CHALLENGE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/challenge.b64'), encoding: 'utf8'
NEGOTIATE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate.b64'), encoding: 'utf8'
NEGOTIATE_CUSTOM_HOSTNAME = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate-custom-hostname.b64'), encoding: 'utf8'
CREATE_ITEM_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/createItemResponse.xml'), encoding: 'utf8'
USER_SETTINGS_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/userSettingsResponse.xml'), encoding: 'utf8'
UPDATE_ITEM_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/updateItemResponse.xml')


describe 'Exchange', ->
  beforeEach ->
    @server = shmock()
    enableDestroy @server

  afterEach (done) ->
    @server.destroy done

  describe 'when the authHostname is inferred', ->
    beforeEach ->
      {port} = @server.address()
      @sut = new Exchange protocol: 'http', hostname: "localhost", port: port, username: 'foo@biz.biz', password: 'bar'

    describe 'authenticate', ->
      describe 'when the credentials are valid', ->
        beforeEach (done) ->
          @server
            .post '/EWS/Exchange.asmx'
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
            .post '/EWS/Exchange.asmx'
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
            .post '/EWS/Exchange.asmx'
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

    describe 'whoami', ->
      describe 'when the credentials are valid', ->
        beforeEach (done) ->
          @negotiate = @server
            .post '/autodiscover/autodiscover.svc'
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
            id:   'ada48c41-66c9-407b-bf2a-a7880e611435'
          }

      describe 'when the credentials are invalid', ->
        beforeEach (done) ->
          @negotiate = @server
            .post '/autodiscover/autodiscover.svc'
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
            attendees: ['blah@whatever.net', 'imdone@whocares.net']
            reminder: '2016-09-08T23:00:00-01:00'
            start: '2016-09-09T00:29:00Z'
            end: '2016-09-09T01:00:00Z'
            location: 'Pokémon Go Home'

          @negotiate = @server
            .post '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @createItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 201, CREATE_ITEM_RESPONSE

          @sut.createItem options, (error, @item) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should create a calendar item request to the exchange server', ->

          expect(@item.Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage).to.containSubset
            "Items":
              "CalendarItem":
                "ItemId":
                  "$":
                    "ChangeKey": "AChangeKey"
                    "Id": "AnId"


    describe 'updateItem', ->
      describe 'when creating an item is successful', ->
        beforeEach (done) ->
          options =
            Id: 'AnId'
            changeKey: 'AChangeKey'
            subject: 'Feed the Trolls'
            attendees: ['no@sleep.net', 'til@brooklyn.net']
            start: '2016-09-10T00:29:00Z'
            end: '2016-09-10T01:00:00Z'
            location: 'Mexico?'

          @negotiate = @server
            .post '/EWS/Exchange.asmx'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @updateItem = @server
            .post '/EWS/Exchange.asmx'
            .reply 201, UPDATE_ITEM_RESPONSE

          @sut.updateItem options, (error, @item) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should send update an item request to the exchange server', ->
          expect(@item.Envelope.Body.UpdateItemResponse.ResponseMessages.UpdateItemResponseMessage).to.containSubset
            "Items":
              "CalendarItem":
                "ItemId":
                  "$":
                    "ChangeKey": "AChangeKey"
                    "Id": "AnId"


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
          .post '/autodiscover/autodiscover.svc'
          .set 'Authorization', NEGOTIATE_CUSTOM_HOSTNAME
          .reply 401, '', {'WWW-Authenticate': CHALLENGE}

        @getUser = @server
          .post '/autodiscover/autodiscover.svc'
          .reply 201

        @sut.whoami done

      it 'should make a negotiate request to the exchange server with the given authHostname', ->
        expect(@negotiate.isDone).to.be.true