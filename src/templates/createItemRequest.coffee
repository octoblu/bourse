_ = require 'lodash'

module.exports = _.template """
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013" />
    <t:TimeZoneContext>
      <t:TimeZoneDefinition Id="<%= itemTimeZone %>" />
    </t:TimeZoneContext>
  </soap:Header>
  <soap:Body>
    <m:CreateItem SendMeetingInvitations="<%= itemSendTo %>" >
      <m:Items>
        <t:CalendarItem>
          <t:Subject><%= itemSubject %></t:Subject>
          <t:Body BodyType="HTML"><%= itemBody %></t:Body>
          <t:ReminderDueBy><%= itemReminder %></t:ReminderDueBy>
          <t:Start><%= itemStart %></t:Start>
          <t:End><%= itemEnd %></t:End>
          <t:Location><%= itemLocation %></t:Location>
        </t:CalendarItem>
      </m:Items>
    </m:CreateItem>
  </soap:Body>
</soap:Envelope>
"""
