_ = require 'lodash'

module.exports = _.template """
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
      xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
      xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
   <soap:Header>
      <t:RequestServerVersion Version="Exchange2013" />
   </soap:Header>
   <soap:Body>
      <m:UpdateItem ConflictResolution="AlwaysOverwrite" SendMeetingInvitationsOrCancellations="SendToAllAndSaveCopy">
         <m:ItemChanges>
            <t:ItemChange>
               <t:ItemId Id="<%= Id %>" ChangeKey="<%= changeKey %>" />
                  <t:Updates>
                     <t:SetItemField>
                        <t:FieldURI FieldURI="item:Subject" />
                        <t:CalendarItem>
                           <t:Subject><%= itemSubject %></t:Subject>
                        </t:CalendarItem>
                     </t:SetItemField>
                     <t:SetItemField>
                       <t:FieldURI FieldURI="calendar:Location" />
                       <t:CalendarItem>
                          <t:Location><%= itemLocation %></t:Location>
                       </t:CalendarItem>
                     </t:SetItemField>
                     <t:SetItemField>
                       <t:FieldURI FieldURI="calendar:Start" />
                       <t:CalendarItem>
                         <t:Start><%= itemStart %></t:Start>
                       </t:CalendarItem>
                     </t:SetItemField>
                     <t:SetItemField>
                       <t:FieldURI FieldURI="calendar:End" />
                       <t:CalendarItem>
                         <t:End><%= itemEnd %></t:End>
                       </t:CalendarItem>
                     </t:SetItemField>
                     <t:SetItemField>
                      <t:FieldURI FieldURI="calendar:RequiredAttendees" />
                      <t:CalendarItem>
                         <t:RequiredAttendees>
                           <% _.each(itemAttendees, function(attendee) { %>
                           <t:Attendee>
                             <t:Mailbox>
                               <t:EmailAddress><%= attendee %></t:EmailAddress>
                               <t:RoutingType>SMTP</t:RoutingType>
                               <t:MailboxType>Mailbox</t:MailboxType>
                             </t:Mailbox>
                           </t:Attendee>
                           <% }) %>
                        </t:RequiredAttendees>
                     </t:CalendarItem>
                  </t:SetItemField>
               </t:Updates>
            </t:ItemChange>
         </m:ItemChanges>
      </m:UpdateItem>
   </soap:Body>
</soap:Envelope>
"""
