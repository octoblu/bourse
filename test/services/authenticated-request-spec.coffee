{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'

shmock = require 'shmock'
enableDestroy = require 'server-destroy'

AuthenticatedRequest = require '../../src/services/authenticated-request'

describe 'AuthenticatedRequest', ->
  beforeEach ->
    @responseDelay = 0
    delayResponse = (req, res, next) => setTimeout next, @responseDelay
    @server = shmock null, [delayResponse]
    enableDestroy @server

  afterEach (done) ->
    @server.destroy done

  describe '->getOpenEwsRequest', ->
    describe 'when the request times out', ->
      beforeEach (done) ->
        @responseDelay = 10000

        @sut = new AuthenticatedRequest
          timeout: 1
          protocol: 'http'
          hostname: 'localhost'
          port: @server.address().port
          username: 'a'
          password: 'b'

        @sut.getOpenEwsRequest {}, (@error) => done()

      it 'should yield an error', ->
        expect(=> throw @error).to.throw 'ETIMEDOUT'
        expect(@error.message).to.deep.equal 'ETIMEDOUT'
