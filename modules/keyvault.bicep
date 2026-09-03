// =============================================================================
// Key Vault (RBAC, private-network only)
// =============================================================================
@description('Key Vault name (globally unique, 3-24 chars).')
param name string

@description('Location for the resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Log Analytics workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Principal ID of an admin to grant Key Vault Administrator. Empty to skip.')
param adminPrincipalId string = ''

@description('Principal ID of the app managed identity to grant Key Vault Secrets User.')
param appIdentityPrincipalId string

@description('Application Insights connection string to store as a Key Vault secret.')
@secure()
param appInsightsConnectionString string

// Built-in role definition IDs
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource appInsightsConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'appinsights-connection-string'
  properties: {
    value: appInsightsConnectionString
  }
}

resource secretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appIdentityPrincipalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    principalId: appIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

resource adminAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(adminPrincipalId)) {
  name: guid(keyVault.id, adminPrincipalId, keyVaultAdministratorRoleId)
  scope: keyVault
  properties: {
    principalId: adminPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
  }
}

output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
