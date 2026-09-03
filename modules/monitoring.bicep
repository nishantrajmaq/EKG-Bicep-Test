// =============================================================================
// Monitoring: Log Analytics + Application Insights + Action Group
// =============================================================================
@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Application Insights component name.')
param appInsightsName string

@description('Action group name.')
param actionGroupName string

@description('Location for the resources.')
param location string

@description('Tags applied to the resources.')
param tags object

@description('Retention in days for the Log Analytics workspace.')
param retentionInDays int = 30

@description('Email receivers for the action group. Each item: { name, email }.')
param emailReceivers array = []

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take(replace(actionGroupName, '-', ''), 12)
    enabled: true
    emailReceivers: [
      for r in emailReceivers: {
        name: r.name
        emailAddress: r.email
        useCommonAlertSchema: true
      }
    ]
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
output appInsightsId string = appInsights.id
@secure()
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output actionGroupId string = actionGroup.id
