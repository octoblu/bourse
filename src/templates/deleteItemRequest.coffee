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
        <m:CreateItem MessageDisposition="SaveOnly">
           <m:Items>
              <t:CancelCalendarItem>
                 <t:ReferenceItemId Id="<%= Id %>" ChangeKey="<%= changeKey %>" />
                 <t:NewBodyContent BodyType="Text"><%= cancelReason %></t:NewBodyContent>
              </t:CancelCalendarItem>
           </m:Items>
        </m:CreateItem>
     </soap:Body>
  </soap:Envelope>
"""
