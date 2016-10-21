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
        <t:TimeZoneDefinition Id="<%= timeZone %>" />
      </t:TimeZoneContext>
    </soap:Header>
    <soap:Body>
      <m:CreateItem SendMeetingInvitations="<%= sendTo %>" >
        <m:Items>
          <t:CalendarItem>
            <t:Subject><%= subject %></t:Subject>
            <t:Body BodyType="HTML"><%= body %></t:Body>
            <t:ReminderDueBy><%= reminder %></t:ReminderDueBy>
            <t:Start><%= start %></t:Start>
            <t:End><%= end %></t:End>
            <t:Location><%= location %></t:Location>
            <t:RequiredAttendees>
              <% _.each(attendees, function(attendee) { %>
                <t:Attendee>
                  <t:Mailbox>
                    <t:EmailAddress><%= attendee %></t:EmailAddress>
                    <t:RoutingType>SMTP</t:RoutingType>
                    <t:MailboxType>Mailbox</t:MailboxType>
                  </t:Mailbox>
                </t:Attendee>
              <% }) %>
            </t:RequiredAttendees>
            <t:ExtendedProperty>
              <% _.each(extendedProperties, function(value, key) { %>
                <t:ExtendedFieldURI DistinguishedPropertySetId="InternetHeaders"
                                    PropertyName="X-<%= key %>"
                                    PropertyType="String" />
                <t:Value><%= value %></t:Value>
              <% }) %>
            </t:ExtendedProperty>
          </t:CalendarItem>
        </m:Items>
      </m:CreateItem>
    </soap:Body>
  </soap:Envelope>
"""
