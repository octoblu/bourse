_ = require 'lodash'

module.exports = _.template """
  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
         xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
         xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
      <t:RequestServerVersion Version="Exchange2007_SP1" />
    </soap:Header>
    <soap:Body>
      <m:FindItem Traversal="Shallow">
        <m:ItemShape>
          <t:BaseShape>IdOnly</t:BaseShape>
        </m:ItemShape>
        <m:CalendarView MaxEntriesReturned="100" StartDate="<%= start.format() %>" EndDate="<%= end.format() %>" />
        <m:ParentFolderIds>
          <t:DistinguishedFolderId Id="calendar" />
        </m:ParentFolderIds>
      </m:FindItem>
    </soap:Body>
  </soap:Envelope>
"""
