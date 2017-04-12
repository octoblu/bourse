_ = require 'lodash'

module.exports = _.template """
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
   <soap:Header>
      <t:RequestServerVersion Version="Exchange2010" />
   </soap:Header>
   <soap:Body>
      <m:CreateItem MessageDisposition="SendAndSaveCopy">
         <m:Items>
            <t:ForwardItem>
               <t:ToRecipients>
                  <t:Mailbox>
                     <t:EmailAddress><%= email %></t:EmailAddress>
                  </t:Mailbox>
               </t:ToRecipients>
               <t:ReferenceItemId Id="<%= itemId %>" ChangeKey="<%= changeKey %>" />
               <t:NewBodyContent BodyType="Text">Forwarded from Smartspaces</t:NewBodyContent>
            </t:ForwardItem>
         </m:Items>
      </m:CreateItem>
   </soap:Body>
</soap:Envelope>
"""
