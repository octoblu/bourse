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
    <m:UpdateUserConfiguration>
      <m:UserConfiguration>
        <t:UserConfigurationName Name="Calendar">
          <t:DistinguishedFolderId Id="calendar" />
        </t:UserConfigurationName>

        <t:Dictionary>
          <% if (_.isBoolean(piAutoProcess)) { %>
            <t:DictionaryEntry>
              <t:DictionaryKey>
                <t:Type>String</t:Type>
                <t:Value>piAutoProcess</t:Value>
              </t:DictionaryKey>
              <t:DictionaryValue>
                <t:Type>Boolean</t:Type>
                <t:Value><%= piAutoProcess %></t:Value>
              </t:DictionaryValue>
            </t:DictionaryEntry>
          <% } %>

          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piShowWorkHourOnly</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Integer32</t:Type>
              <t:Value>1</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piReminderUpgradeTime</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Integer32</t:Type>
              <t:Value>218722219</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piAutoDeleteReceipts</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Boolean</t:Type>
              <t:Value>false</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piRemindDefault</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Integer32</t:Type>
              <t:Value>15</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piShowFreeItems</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Integer32</t:Type>
              <t:Value>0</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piGroupCalendarShowCoworkers</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Boolean</t:Type>
              <t:Value>true</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piGroupCalendarShowMyDepartment</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Boolean</t:Type>
              <t:Value>true</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>piGroupCalendarShowDirectReports</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Boolean</t:Type>
              <t:Value>true</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
          <t:DictionaryEntry>
            <t:DictionaryKey>
              <t:Type>String</t:Type>
              <t:Value>OLPrefsVersion</t:Value>
            </t:DictionaryKey>
            <t:DictionaryValue>
              <t:Type>Integer32</t:Type>
              <t:Value>1</t:Value>
            </t:DictionaryValue>
          </t:DictionaryEntry>
        </t:Dictionary>

      </m:UserConfiguration>
    </m:UpdateUserConfiguration>
  </soap:Body>
</soap:Envelope>
"""
