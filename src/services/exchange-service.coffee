_      = require 'lodash'
moment = require 'moment'

AuthenticatedRequest = require './authenticated-request'
ExchangeStream       = require '../streams/exchange-stream'

createItemRequest         = require '../templates/createItemRequest'
deleteItemRequest         = require '../templates/deleteItemRequest'
getIdAndKey               = require '../templates/getIdAndKey'
getInboxRequest           = require '../templates/getInboxRequest'
getItemRequest            = require '../templates/getItemRequest'
getItems                  = require '../templates/getItems'
getStreamingEventsRequest = require '../templates/getStreamingEventsRequest'
getSubscriptionRequest    = require '../templates/getSubscriptionRequest'
getUserSettingsRequest    = require '../templates/getUserSettingsRequest'
updateItemRequest         = require '../templates/updateItemRequest'

SUBSCRIPTION_ID_PATH = 'Envelope.Body.SubscribeResponse.ResponseMessages.SubscribeResponseMessage.SubscriptionId'
# MEETING_RESPONSE_PATH = 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.Items'

class Exchange
  constructor: ({protocol, hostname, port, @username, @password, authHostname}) ->
    throw new Error 'Missing required parameter: hostname' unless hostname?
    throw new Error 'Missing required parameter: username' unless @username?
    throw new Error 'Missing required parameter: password' unless @password?

    protocol ?= 'https'
    port ?= 443

    @connectionOptions = {protocol, hostname, port, @username, @password, authHostname}
    @authenticatedRequest = new AuthenticatedRequest @connectionOptions

  authenticate: (callback) =>
    @authenticatedRequest.doEws body: getInboxRequest(), (error, response, extra) =>
      return callback error if error?
      {statusCode} = extra
      return callback @_errorWithCode(statusCode, "5xx Error received: #{statusCode}") if statusCode >= 500

      callback null, (statusCode == 200), {statusCode}

  createItem: ({ timeZone, sendTo, subject, body, reminder, start, end, location, attendees }, callback) =>
    body = createItemRequest({ timeZone, sendTo, subject, body, reminder, start, end, location, attendees })
    @authenticatedRequest.doEws { body }, (error, response) =>
      return callback error if error?
      return callback @_parseCreateItemErrorResponse response if @_isCreateItemError response
      return callback null, @_parseCreateItemResponse response

  deleteItem: ({Id, changeKey, cancelReason}, callback) =>
    @authenticatedRequest.doEws body: deleteItemRequest({Id, changeKey, cancelReason}), (error, response) =>
      return callback error if error?
      return callback null, @_parseDeleteItemResponse response

  getIDandKey: ({distinguishedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getIdAndKey({ distinguishedFolderId }), (error, response) =>
      return callback error if error?
      return callback null, response

  getItemByItemId: (itemId, callback) =>
    @authenticatedRequest.doEws body: getItemRequest({ itemId}), (error, response) =>
      return callback error if error?
      return callback null, response

  getItems: (Id, changeKey, maxEntries, startDate, endDate, callback) =>
    @authenticatedRequest.doEws body: getItems({ Id, changeKey, maxEntries, startDate, endDate }), (error, response) =>
      return callback error if error?
      return callback null, response

  getStreamingEvents: ({distinguishedFolderId}, callback) =>
    @_getSubscriptionId {distinguishedFolderId}, (error, subscriptionId) =>
      return callback error if error?

      @authenticatedRequest.getOpenEwsRequest body: getStreamingEventsRequest({ subscriptionId }), (error, request) =>
        return callback error if error?
        return callback null, new ExchangeStream {@connectionOptions, request}

  getStreamingEventsRequest: ({subscriptionId}, callback) =>
    @authenticatedRequest.getOpenEwsRequest body: getStreamingEventsRequest({ subscriptionId }), (error, response) =>
      return callback error if error?
      return callback null, response

  getUserSettingsRequest: ({username}, callback) =>
    @authenticatedRequest.doAutodiscover body: getUserSettingsRequest({ username }), (error, response) =>
      return callback error if error?
      @_parseUserSettingsResponse response, callback

  updateItem: (options, callback) =>
    @authenticatedRequest.doEws body: updateItemRequest(options), (error, response) =>
      return callback error if error?
      return callback @_parseUpdateItemErrorResponse response if @_isUpdateItemError response
      return callback null, @_parseUpdateItemResponse response

  whoami: (callback) =>
    @authenticatedRequest.doAutodiscover body: getUserSettingsRequest({@username}), (error, response, extra) =>
      return callback error if error?
      return callback @_errorWithCode(401, 'Unauthorized') if extra.statusCode == 401
      @_parseUserSettingsResponse response, callback

  _errorWithCode: (code, message) =>
    error = new Error message
    error.code = code
    return error

  _getSubscriptionId: ({distinguishedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getSubscriptionRequest({distinguishedFolderId}), (error, response) =>
      return callback error if error
      return callback null, _.get(response, SUBSCRIPTION_ID_PATH)

  _isCreateItemError: (response) =>
    responseMessage = _.get response, 'Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage'
    return 'Error' == _.get responseMessage, '$.ResponseClass'

  _isUpdateItemError: (response) =>
    responseMessage = _.get response, 'Envelope.Body.UpdateItemResponse.ResponseMessages.UpdateItemResponseMessage'
    return 'Error' == _.get responseMessage, '$.ResponseClass'

  _normalizeDatetime: (datetime) =>
    moment(datetime).utc().format()

  _parseAttendee: (requiredAttendee) =>
    {
      name: _.get requiredAttendee, 'Mailbox.Name'
      email: _.get requiredAttendee, 'Mailbox.EmailAddress'
    }

  _parseAttendees: (meetingRequest) =>
    requiredAttendees = _.get meetingRequest, 'RequiredAttendees.Attendee'
    _.map requiredAttendees, @_parseAttendee

  _parseCreateItemErrorResponse: (response) =>
    responseMessage = _.get response, 'Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage'
    message = _.get responseMessage, 'MessageText'

    error = new Error "Unprocessable Entity: #{message}"
    error.code = 422
    return error

  _parseCreateItemResponse: (response) =>
    ResponseMessage = _.get response, 'Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage'
    Item = _.get ResponseMessage, 'Items.CalendarItem'
    {
      itemId:    _.get Item, 'ItemId.$.Id'
      changeKey: _.get Item, 'ItemId.$.ChangeKey'
    }

  _parseDeleteItemResponse: (response) =>
    ResponseMessage = _.get response, 'Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage'
    Item = _.get ResponseMessage, 'Items.CalendarItem'
    {
      itemId:    _.get Item, 'ItemId.$.Id'
      changeKey: _.get Item, 'ItemId.$.ChangeKey'
    }

  _parseUpdateItemErrorResponse: (response) =>
    responseMessage = _.get response, 'Envelope.Body.UpdateItemResponse.ResponseMessages.UpdateItemResponseMessage'
    message = _.get responseMessage, 'MessageText'

    error = new Error "Unprocessable Entity: #{message}"
    error.code = 422
    return error

  _parseUpdateItemResponse: (response) =>
    ResponseMessage = _.get response, 'Envelope.Body.UpdateItemResponse.ResponseMessages.UpdateItemResponseMessage'
    Item = _.get ResponseMessage, 'Items.CalendarItem'
    {
      itemId:    _.get Item, 'ItemId.$.Id'
      changeKey: _.get Item, 'ItemId.$.ChangeKey'
    }

  _parseUserSettingsResponse: (response, callback) =>
    UserResponse = _.get response, 'Envelope.Body.GetUserSettingsResponseMessage.Response.UserResponses.UserResponse'
    UserSettings = _.get UserResponse, 'UserSettings.UserSetting'

    name = _.get _.find(UserSettings, Name: 'UserDisplayName'), 'Value'
    id   = _.get _.find(UserSettings, Name: 'UserDeploymentId'), 'Value'

    return callback null, { name, id }

module.exports = Exchange
