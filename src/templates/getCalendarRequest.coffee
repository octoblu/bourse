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
      <m:GetFolder>
        <m:FolderShape>
          <t:BaseShape>IdOnly</t:BaseShape>
        </m:FolderShape>
        <m:FolderIds>
          <t:DistinguishedFolderId Id=<%= distinguisedFolderId %> />
        </m:FolderIds>
      </m:GetFolder>
    </soap:Body>
  </soap:Envelope>
"""
