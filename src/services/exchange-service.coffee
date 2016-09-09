_ = require 'lodash'

AuthenticatedRequest = require './authenticated-request'
ExchangeStream       = require '../streams/exchange-stream'

getStreamingEventsRequest = require '../templates/getStreamingEventsRequest'
getSubscriptionRequest    = require '../templates/getSubscriptionRequest'
getUserSettingsRequest    = require '../templates/getUserSettingsRequest'
createItemRequest         = require '../templates/createItemRequest'

SUBSCRIPTION_ID_PATH = 'Envelope.Body.SubscribeResponse.ResponseMessages.SubscribeResponseMessage.SubscriptionId'

class Exchange
  constructor: ({protocol, hostname, port, @username, @password, authHostname}) ->
    throw new Error 'Missing required parameter: hostname' unless hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    protocol ?= 'https'
    port ?= 443

    @connectionOptions = {protocol, hostname, port, @username, @password, authHostname}
    @authenticatedRequest = new AuthenticatedRequest @connectionOptions

  createItem: (options, callback) =>
    @authenticatedRequest.doEws body: createItemRequest(options), (error, request) =>
      return callback error if error?
      return callback null, request

  getStreamingEvents: ({distinguisedFolderId}, callback) =>
    @_getSubscriptionId {distinguisedFolderId}, (error, subscriptionId) =>
      return callback error if error?

      @authenticatedRequest.getOpenEwsRequest body: getStreamingEventsRequest({ subscriptionId }), (error, request) =>
        return callback error if error?
        return callback null, new ExchangeStream {@connectionOptions, request}

  whoami: (callback) =>
    @authenticatedRequest.doAutodiscover body: getUserSettingsRequest({@username}), (error, response, extra) =>
      return callback error if error?
      return callback @_errorWithCode(401, 'Unauthorized') if extra.statusCode == 401
      @_parseUserSettingsResponse response, callback

  _errorWithCode: (code, message) =>
    error = new Error message
    error.code = code
    return error

  _getSubscriptionId: ({distinguisedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getSubscriptionRequest({distinguisedFolderId}), (error, response) =>
      return callback error if error
      return callback null, _.get(response, SUBSCRIPTION_ID_PATH)

  _parseUserSettingsResponse: (response, callback) =>
    UserResponse = _.get response, 'Envelope.Body.GetUserSettingsResponseMessage.Response.UserResponses.UserResponse'
    UserSettings = _.get UserResponse, 'UserSettings.UserSetting'

    name = _.get _.find(UserSettings, Name: 'UserDisplayName'), 'Value'
    id   = _.get _.find(UserSettings, Name: 'UserDeploymentId'), 'Value'

    return callback null, { name, id }

module.exports = Exchange
