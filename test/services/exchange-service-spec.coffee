{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
_ = require 'lodash'
fs = require 'fs'
path = require 'path'
shmock = require 'shmock'
enableDestroy = require 'server-destroy'

Exchange = require '../../src/services/exchange-service'
CHALLENGE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/challenge.b64'), encoding: 'utf8'
NEGOTIATE = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate.b64'), encoding: 'utf8'
NEGOTIATE_CUSTOM_HOSTNAME = _.trim fs.readFileSync path.join(__dirname, '../fixtures/negotiate-custom-hostname.b64'), encoding: 'utf8'
USER_SETTINGS_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/userSettingsResponse.xml'), encoding: 'utf8'
UPDATE_ITEM_CALENDAR_RESPONSE = fs.readFileSync path.join(__dirname, '../fixtures/updateItemCalendarResponse.xml')


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

    xdescribe 'updateCalendarItem', ->
      describe 'when the update is successful', ->
        beforeEach (done) ->
          @negotiate = @server
            .post '/autodiscover/autodiscover.svc'
            .set 'Authorization', NEGOTIATE
            .reply 401, '', {'WWW-Authenticate': CHALLENGE}

          @updateCalendarItem = @server
            .post '/autodiscover/autodiscover.svc'
            .reply 200, UPDATE_ITEM_CALENDAR_RESPONSE

          @sut.updateCalendarItem options, (error, @item) => done error

        it 'should make a negotiate request to the exchange server', ->
          expect(@negotiate.isDone).to.be.true

        it 'should make an update calendar request to the exchange server', ->
          expect(@updateCalendarItem.isDone).to.be.true
        

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
