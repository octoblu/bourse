_         = require 'lodash'
moment    = require 'moment'
url       = require 'url'
urlregexp = require 'urlregexp'

debug = require('debug')('bourse:exchange-service')

AuthenticatedRequest = require './authenticated-request'
ExchangeStream       = require '../streams/exchange-stream'

createItemRequest              = require '../templates/createItemRequest'
deleteItemRequest              = require '../templates/deleteItemRequest'
getCalendarItemsInRangeRequest = require '../templates/getCalendarItemsInRangeRequest'
getIdAndKey                    = require '../templates/getIdAndKey'
getInboxRequest                = require '../templates/getInboxRequest'
getItemRequest                 = require '../templates/getItemRequest'
getItemsByItemIdsRequest       = require '../templates/getItemsByItemIdsRequest'
getItems                       = require '../templates/getItems'
getStreamingEventsRequest      = require '../templates/getStreamingEventsRequest'
getSubscriptionRequest         = require '../templates/getSubscriptionRequest'
getUserSettingsRequest         = require '../templates/getUserSettingsRequest'
updateItemRequest              = require '../templates/updateItemRequest'

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

  authenticate: (callback) =>
    @authenticatedRequest.doEws body: getInboxRequest(), (error, response, extra) =>
      return callback error if error?
      {statusCode} = extra
      return callback @_errorWithCode(statusCode, "5xx Error received: #{statusCode}") if statusCode >= 500

      callback null, (statusCode == 200), {statusCode}


  _prepareExtendedProperties: (extendedProperties) =>
    _.mapKeys extendedProperties, (value, key) =>
      _.kebabCase key

  createItem: ({ timeZone, sendTo, subject, body, reminder, start, end, location, attendees, extendedProperties }, callback) =>
    extendedProperties = @_prepareExtendedProperties extendedProperties
    body = createItemRequest({ timeZone, sendTo, subject, body, reminder, start, end, location, attendees, extendedProperties })
    @authenticatedRequest.doEws { body }, (error, response, extra) =>
      return callback error if error?
      return callback new Error("Non 200 status code: #{extra.statusCode}") if extra.statusCode != 200
      return callback @_parseCreateItemErrorResponse response if @_isCreateItemError response
      return callback null, @_parseCreateItemResponse response

  deleteItem: ({Id, changeKey, cancelReason}, callback) =>
    @authenticatedRequest.doEws body: deleteItemRequest({Id, changeKey, cancelReason}), (error, response) =>
      return callback error if error?
      return callback null, @_parseDeleteItemResponse response

  getCalendarItemsInRange: ({ start, end, extendedProperties }, callback) =>
    start = moment.utc start
    end   = moment.utc end
    body = getCalendarItemsInRangeRequest({ start, end })
    @authenticatedRequest.doEws { body }, (error, response, extra) =>
      return callback error if error?
      return callback new Error("Non 200 status code: #{extra.statusCode}") if extra.statusCode != 200
      return callback @_parseCalendarItemsInRangeErrorResponse response if @_isCalendarItemsInRangeError response
      itemIds = @_parseCalendarItemsInRangeResponse response
      return callback null, [], extra if _.isEmpty itemIds
      @_getItemsByItemIds {itemIds, extendedProperties}, callback

  getIDandKey: ({distinguishedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getIdAndKey({ distinguishedFolderId }), (error, response) =>
      return callback error if error?
      return callback null, response

  getItem: ({itemId}, callback) =>
    @authenticatedRequest.doEws body: getItemRequest({itemId}), (error, response, extra) =>
      return callback error if error?
      return callback new Error("Non 200 status code: #{extra.statusCode}") if extra.statusCode != 200
      return callback new Error('Empty Response') unless response?
      return callback new Error('Item Not Found') if @_isItemNotFound response
      return callback null, @_parseGetItemResponse response

  getItemByItemId: (itemId, callback) =>
    @getItem {itemId}, callback

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
    # they must exist
    options.subject ?= null
    options.end ?= null
    options.start ?= null
    options.location ?= null
    debug 'updateItem-options', options
    debug 'updateItem', updateItemRequest(options)
    @authenticatedRequest.doEws body: updateItemRequest(options), (error, response, extra) =>
      return callback error if error?
      return callback new Error("Non 200 status code: #{extra.statusCode}") if extra.statusCode != 200
      return callback @_parseUpdateItemErrorResponse response if @_isUpdateItemError response
      return callback null, @_parseUpdateItemResponse response

  whoami: (callback) =>
    @authenticatedRequest.doAutodiscover body: getUserSettingsRequest({@username}), (error, response, extra) =>
      return callback error if error?
      return callback @_errorWithCode(401, 'Unauthorized'), null, extra if extra.statusCode == 401
      @_parseUserSettingsResponse response, (error, userSettings) =>
        return callback error, null, extra if error?
        return callback null, userSettings, extra

  _errorWithCode: (code, message) =>
    error = new Error message
    error.code = code
    return error

  _getItemsByItemIds: ({ itemIds, extendedProperties }, callback) =>
    extendedProperties = @_prepareExtendedProperties extendedProperties
    @authenticatedRequest.doEws body: getItemsByItemIdsRequest({itemIds, extendedProperties}), (error, response, extra) =>
      return callback error if error?
      return callback new Error("Non 200 status code: #{extra.statusCode}") if extra.statusCode != 200
      return callback @_parseGetItemsErrorResponse response if @_isGetItemsError response
      return callback null, @_parseGetItemsResponse response

  _getSubscriptionId: ({distinguishedFolderId}, callback) =>
    @authenticatedRequest.doEws body: getSubscriptionRequest({distinguishedFolderId}), (error, response) =>
      return callback error if error
      return callback null, _.get(response, SUBSCRIPTION_ID_PATH)

  _isCalendarItemsInRangeError: (response) =>
    responseMessage = _.get response, 'Envelope.Body.FindItemResponse.ResponseMessages.FindItemResponseMessage'
    responseClass   = _.get responseMessage, '$.ResponseClass'

    return responseClass == 'Error'

  _isCreateItemError: (response) =>
    responseMessage = _.get response, 'Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage'
    return 'Error' == _.get responseMessage, '$.ResponseClass'

  _isGetItemsError: (response) =>
    responseMessage = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage'
    return 'Error' == _.get responseMessage, '$.ResponseClass'

  _isItemNotFound: (response) =>
    responseCode = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.ResponseCode'
    return responseCode == 'ErrorItemNotFound'

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

  _parseCalendarItemsInRangeErrorResponse: (response) =>
    responseMessage = _.get response, 'Envelope.Body.FindItemResponse.ResponseMessages.FindItemResponseMessage'
    error = new Error _.get(responseMessage, 'MessageText')
    error.code = 422
    return error

  _parseCalendarItemsInRangeResponse: (response) =>
    responseMessages = _.get response, 'Envelope.Body.FindItemResponse.ResponseMessages'
    items = _.castArray _.get responseMessages, 'FindItemResponseMessage.RootFolder.Items.CalendarItem'
    validItems = _.reject items, {'IsCancelled': 'true'}
    _.compact _.map(validItems, 'ItemId.$.Id')

  _parseGetItemsErrorResponse: (response) =>
    responseMessage = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage'
    error = new Error _.get(responseMessage, 'MessageText')
    error.code = 422
    return error

  _parseGetItemResponse: (response) =>
    items = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage.Items'
    meetingRequest = _.first _.values items
    @_parseMeetingRequest meetingRequest

  _parseMeetingRequest: (meetingRequest) =>
    return {
      subject: _.get meetingRequest, 'Subject'
      startTime: @_normalizeDatetime _.get(meetingRequest, 'StartWallClock')
      endTime:   @_normalizeDatetime _.get(meetingRequest, 'EndWallClock')
      accepted: "Accept" == _.get(meetingRequest, 'ResponseType')
      eventType: 'modified'
      itemId: _.get meetingRequest, 'ItemId.$.Id'
      changeKey: _.get meetingRequest, 'ItemId.$.ChangeKey', null
      location: _.get meetingRequest, 'Location'
      recipient:
        name: _.get meetingRequest, 'ReceivedBy.Mailbox.Name'
        email: _.get meetingRequest, 'ReceivedBy.Mailbox.EmailAddress'
      organizer:
        name: _.get meetingRequest, 'Organizer.Mailbox.Name'
        email: _.get meetingRequest, 'Organizer.Mailbox.EmailAddress'
      attendees: @_parseAttendees(meetingRequest)
      urls: @_parseUrls(meetingRequest)
      extendedProperties: @_parseExtendedProperties(meetingRequest)
    }

  _parseExtendedProperties: (response) =>
    extendedProperties = _.castArray _.get response, 'ExtendedProperty'
    result = {}
    _.each extendedProperties, (extendedFieldURI) =>
      propertyName = _.get extendedFieldURI, 'ExtendedFieldURI.$.PropertyName'
      name = _.camelCase propertyName?.replace /X-/, ''
      value = _.get extendedFieldURI, 'Value'
      result[name] = value
    return result

  _parseGetItemsResponse: (response) =>
    ResponseMessages = _.get response, 'Envelope.Body.GetItemResponse.ResponseMessages'
    GetItemResponseMessages = _.castArray _.get(ResponseMessages, 'GetItemResponseMessage')
    meetingRequests = _.map GetItemResponseMessages, 'Items.CalendarItem'

    _.map meetingRequests, @_parseMeetingRequest

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

  _parseUrls: (meetingRequest) =>
    body    = _.get meetingRequest, 'Body._', ''
    matches = body.match urlregexp
    matches = _.reject matches, (match) => _.includes match, 'span'

    groupedUrls = {}

    _.each matches, (match) =>
      parsed = url.parse match
      path = @_reverseHostname parsed.hostname

      urls = _.get(groupedUrls, path, [])
      urls.push {url: match}
      _.set groupedUrls, path, urls

    return groupedUrls

  _parseUserSettingsResponse: (response, callback) =>
    UserResponse = _.get response, 'Envelope.Body.GetUserSettingsResponseMessage.Response.UserResponses.UserResponse'
    UserSettings = _.get UserResponse, 'UserSettings.UserSetting'

    name = _.get _.find(UserSettings, Name: 'UserDisplayName'), 'Value'

    return callback null, { name }

  _reverseHostname: (hostname) => # meet.citrix.com => com.citrix.meet
    levels = _.reverse _.split(hostname, '.')
    return _.join levels, '.'

module.exports = Exchange
