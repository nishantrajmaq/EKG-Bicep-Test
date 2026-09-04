// =============================================================================
// Container Apps Managed Environment (VNet integrated)
// =============================================================================
@description('Container Apps environment name.')
param name string

@description('Location for the resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Infrastructure subnet ID (delegated to Microsoft.App/environments).')
param infrastructureSubnetId string

@description('Log Analytics workspace resource ID.')
param logAnalyticsWorkspaceId string

@description('Application Insights connection string.')
@secure()
param appInsightsConnectionString string

@description('Deploy the environment as internal-only (no public ingress).')
param internalOnly bool = true

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(logAnalyticsWorkspaceId, '/'))
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: appInsightsConnectionString
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: internalOnly
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    zoneRedundant: true
  }
}

output environmentId string = environment.id
output environmentName string = environment.name
output defaultDomain string = environment.properties.defaultDomain
output staticIp string = environment.properties.staticIp
