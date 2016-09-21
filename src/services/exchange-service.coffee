_      = require 'lodash'
moment = require 'moment'

AuthenticatedRequest = require './authenticated-request'
ExchangeStream       = require '../streams/exchange-stream'

getInboxRequest           = require '../templates/getInboxRequest'
getStreamingEventsRequest = require '../templates/getStreamingEventsRequest'
getSubscriptionRequest    = require '../templates/getSubscriptionRequest'
getUserSettingsRequest    = require '../templates/getUserSettingsRequest'
createItemRequest         = require '../templates/createItemRequest'
getIdAndKey               = require '../templates/getIdAndKey'
getItems                  = require '../templates/getItems'
deleteCalendarItemRequest = require '../templates/deleteCalendarItemRequest'
updateCalendarItemRequest = require '../templates/updateCalendarItemRequest'

SUBSCRIPTION_ID_PATH = 'Envelope.Body.SubscribeResponse.ResponseMessages.SubscribeResponseMessage.SubscriptionId'
MEETING_RESPONSE_PATH = 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.Items'

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

  createItem: ({ itemTimeZone, itemSendTo, itemSubject, itemBody, itemReminder, itemStart, itemEnd, itemLocation, attendee }, callback) =>
    body = createItemRequest({ itemTimeZone, itemSendTo, itemSubject, itemBody, itemReminder, itemStart, itemEnd, itemLocation, attendee })
    @authenticatedRequest.doEws { body }, (error, response) =>
      return callback error if error?
      return callback null, response

  deleteItem: ({Id, changeKey, cancelReason}, callback) =>
    @authenticatedRequest.doEws body: deleteCalendarItemRequest({Id, changeKey, cancelReason}), (error, response) =>
      return callback error if error?
      return callback null, response

  getIDandKey: ({distinguisedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getIdAndKey({ distinguisedFolderId }), (error, response) =>
      return callback error if error?
      return callback null, response

  getItems: (Id, changeKey, maxEntries, startDate, endDate, callback) =>
    @authenticatedRequest.doEws body: getItems({ Id, changeKey, maxEntries, startDate, endDate }), (error, response) =>
      return callback error if error?
      return callback null, response

  getStreamingEvents: ({distinguisedFolderId}, callback) =>
    @_getSubscriptionId {distinguisedFolderId}, (error, subscriptionId) =>
      return callback error if error?

      @authenticatedRequest.getOpenEwsRequest body: getStreamingEventsRequest({ subscriptionId }), (error, response) =>
        return callback error if error?
        return callback null, new ExchangeStream {@connectionOptions, response}

  getStreamingEventsRequest: ({subscriptionId}, callback) =>
    @authenticatedRequest.getOpenEwsRequest body: getStreamingEventsRequest({ subscriptionId }), (error, response) =>
        return callback error if error?
        return callback null, response

  getUserSettingsRequest: ({username}, callback) =>
    @authenticatedRequest.doAutodiscover body: getUserSettingsRequest({ username }), (error, response) =>
      return callback error if error?
      @_parseUserSettingsResponse response, callback

  updateCalendarItem: (options, callback) =>
    @authenticatedRequest.doEws body: updateCalendarItemRequest(options), (error, response) =>
      return callback error if error?
      return callback null, response

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

  _parseItemResponse: (response) =>
    items = _.get response, MEETING_RESPONSE_PATH
    meetingRequest = _.first _.values items

    return {
      subject: _.get meetingRequest, 'Subject'
      startTime: @_normalizeDatetime _.get(meetingRequest, 'itemStart')
      endTime:   @_normalizeDatetime _.get(meetingRequest, 'itemEnd')
      accepted: "Accept" == _.get(meetingRequest, 'ResponseType')
      eventType: 'modified'
      itemId: _.get meetingRequest, 'ItemId.$.Id'
      location:
        name: _.get meetingRequest, 'Location'
      recipient:
        name: _.get meetingRequest, 'ReceivedBy.Mailbox.Name'
        email: _.get meetingRequest, 'ReceivedBy.Mailbox.EmailAddress'
      attendees: @_parseAttendees(meetingRequest)
    }

  _parseUserSettingsResponse: (response, callback) =>
    UserResponse = _.get response, 'Envelope.Body.GetUserSettingsResponseMessage.Response.UserResponses.UserResponse'
    UserSettings = _.get UserResponse, 'UserSettings.UserSetting'

    name = _.get _.find(UserSettings, Name: 'UserDisplayName'), 'Value'
    id   = _.get _.find(UserSettings, Name: 'UserDeploymentId'), 'Value'

    return callback null, { name, id }

module.exports = Exchange
