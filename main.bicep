// =============================================================================
// EKG Platform - Minimal Deployment (resource group scope)
// Deploys core networking, identity, and security resources only
// =============================================================================
targetScope = 'resourceGroup'

// -----------------------------------------------------------------------------
// Parameters - Simplified for core resources
// -----------------------------------------------------------------------------
@description('Short project name used in resource names.')
@minLength(2)
@maxLength(8)
param projectName string = 'ekg'

@description('Environment name (e.g. dev, test, prod).')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string = 'test'

@description('Azure region for all resources.')
param location string

@description('Object ID of the user/service principal that should get Key Vault Administrator.')
param adminPrincipalId string = ''

@description('Deploy Azure Front Door Premium and WAF. Requires a reachable HTTPS origin hostname.')
param deployFrontDoor bool = false

@description('Front Door origin hostname without https://. Required when deployFrontDoor is true.')
param frontDoorOriginHostName string = ''

// -----------------------------------------------------------------------------
// Naming
// -----------------------------------------------------------------------------
var regionAbbreviations = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  westus3: 'wus3'
  centralus: 'cus'
  swedencentral: 'sdc'
  northeurope: 'neu'
  westeurope: 'weu'
  uksouth: 'uks'
  australiaeast: 'aue'
}
var regionCode = regionAbbreviations[?location] ?? take(replace(toLower(location), ' ', ''), 6)

var namePrefix = '${projectName}-${environmentName}-${regionCode}'

var names = {
  vnet: 'vnet-${namePrefix}'
  keyVault: 'kv-${namePrefix}'
  logAnalytics: 'log-${namePrefix}'
  appInsights: 'appi-${namePrefix}'
  actionGroup: 'ag-${namePrefix}'
  managedIdentity: namePrefix
  containerAppsEnv: 'cae-${namePrefix}'
  acr: 'acr${projectName}${environmentName}${regionCode}'
  frontDoorProfile: 'afd-${namePrefix}'
  frontDoorEndpoint: 'afde-${projectName}${environmentName}${regionCode}'
  frontDoorWaf: 'waf-${namePrefix}'
}

// -----------------------------------------------------------------------------
// Managed Identities
// -----------------------------------------------------------------------------
module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    namePrefix: names.managedIdentity
    location: location
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
  }
}

// -----------------------------------------------------------------------------
// Networking (VNet + Subnets + NSGs)
// -----------------------------------------------------------------------------
module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    name: names.vnet
    location: location
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
    workloadSubnetPrefix: '10.20.4.0/24'
  }
}

// -----------------------------------------------------------------------------
// Key Vault with RBAC & Diagnostics
// -----------------------------------------------------------------------------
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    name: names.keyVault
    location: location
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    adminPrincipalId: adminPrincipalId
    appIdentityPrincipalId: identity.outputs.appIdentityPrincipalId
  }
}

// -----------------------------------------------------------------------------
// Private DNS Zones
// -----------------------------------------------------------------------------
module privateDns 'modules/privateDns.bicep' = {
  name: 'privateDns'
  params: {
    vnetId: network.outputs.vnetId
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
  }
}

// -----------------------------------------------------------------------------
// Private Endpoints (for Key Vault only)
// -----------------------------------------------------------------------------
module privateEndpoints 'modules/privateEndpoints.bicep' = {
  name: 'privateEndpoints'
  params: {
    location: location
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
    peSubnetId: network.outputs.peSubnetId
    dnsZoneIds: privateDns.outputs.zoneIds
    keyVaultId: keyVault.outputs.id
    containerRegistryId: containerRegistry.id
  }
}

// -----------------------------------------------------------------------------
// Log Analytics + Application Insights + Action Group
// -----------------------------------------------------------------------------
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: names.logAnalytics
    appInsightsName: names.appInsights
    actionGroupName: names.actionGroup
    location: location
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
    emailReceivers: []
  }
}

// -----------------------------------------------------------------------------
// Azure Container Registry
// -----------------------------------------------------------------------------
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: names.acr
  location: location
  tags: {
    environment: environmentName
    managedBy: 'bicep'
    company: 'MAQ Software'
    createdBy: 'nishantr@maqsoftware.com'
  }
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
  }
}

// -----------------------------------------------------------------------------
// Container Apps Environment
// -----------------------------------------------------------------------------
module containerAppsEnv 'modules/containerAppsEnv.bicep' = {
  name: 'containerAppsEnv'
  params: {
    name: names.containerAppsEnv
    location: location
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
    infrastructureSubnetId: network.outputs.acaSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// -----------------------------------------------------------------------------
// Azure Front Door Premium + WAF (optional)
// -----------------------------------------------------------------------------
module frontDoorWaf 'modules/frontDoorWaf.bicep' = if (deployFrontDoor) {
  name: 'frontDoorWaf'
  params: {
    profileName: names.frontDoorProfile
    endpointName: names.frontDoorEndpoint
    wafPolicyName: names.frontDoorWaf
    originHostName: frontDoorOriginHostName
    tags: {
      environment: environmentName
      managedBy: 'bicep'
      company: 'MAQ Software'
      createdBy: 'nishantr@maqsoftware.com'
    }
  }
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output resourceGroupName string = resourceGroup().name
output location string = location
output vnetId string = network.outputs.vnetId
output privateEndpointsSubnetId string = network.outputs.peSubnetId
output containerAppsSubnetId string = network.outputs.acaSubnetId
output workloadSubnetId string = network.outputs.workloadSubnetId
output keyVaultName string = keyVault.outputs.name
output keyVaultUri string = keyVault.outputs.uri
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output actionGroupId string = monitoring.outputs.actionGroupId
output containerAppsEnvironmentName string = containerAppsEnv.outputs.environmentName
output frontDoorEndpointHostName string = frontDoorWaf.?outputs.endpointHostName ?? ''
