targetScope = 'resourceGroup'

@description('Project name used in resource naming. Lowercase, 3-10 chars.')
@minLength(3)
@maxLength(10)
param projectName string

@description('Deployment environment name used in resource naming.')
@allowed([
  'dev'
  'test'
  'stage'
  'prod'
])
param environmentName string

@description('Azure region for the primary deployment.')
param location string = resourceGroup().location

@description('Object ID of an administrator to grant Key Vault Administrator access. Leave empty to skip.')
param adminPrincipalId string = ''

@description('Whether to deploy Azure Front Door Premium with WAF protection.')
param deployFrontDoor bool = false

@description('Origin hostname for Front Door when deployFrontDoor is true.')
param frontDoorOriginHostName string = ''

@description('Additional Azure regions for Azure Container Registry replicas.')
param acrReplicaLocations array = []

@description('Secondary region for Log Analytics replication.')
param logAnalyticsReplicaLocation string = 'centralus'

var regionCodeMap = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  centralus: 'cus'
  northeurope: 'neu'
  westeurope: 'weu'
}
var regionCode = contains(regionCodeMap, location) ? regionCodeMap[location] : toLower(replace(location, ' ', ''))

var prefix = '${projectName}-${environmentName}-${regionCode}'
var tags = {
  environment: environmentName
  managedBy: 'bicep'
  project: projectName
}

var vnetName = 'vnet-${prefix}'
var keyVaultName = 'kv-${prefix}'
var logAnalyticsName = 'log-${prefix}'
var appInsightsName = 'appi-${prefix}'
var actionGroupName = 'ag-${prefix}'
var acrName = 'acr${toLower(replace(projectName, '-', ''))}${toLower(environmentName)}${regionCode}'
var frontDoorProfileName = 'afd-${prefix}'
var frontDoorEndpointName = 'afde${toLower(replace(projectName, '-', ''))}${toLower(environmentName)}${regionCode}'
var frontDoorWafPolicyName = 'waf-${prefix}'

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    namePrefix: prefix
    location: location
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    name: vnetName
    location: location
    tags: tags
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: logAnalyticsName
    appInsightsName: appInsightsName
    actionGroupName: actionGroupName
    location: location
    replicaLocation: logAnalyticsReplicaLocation
    tags: tags
  }
}

module containerRegistry 'modules/containerRegistry.bicep' = {
  name: 'container-registry'
  params: {
    name: acrName
    location: location
    tags: tags
    sku: 'Standard'
    replicaLocations: acrReplicaLocations
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    adminPrincipalId: adminPrincipalId
    appIdentityPrincipalId: identity.outputs.appIdentityPrincipalId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

module privateDns 'modules/privateDns.bicep' = {
  name: 'private-dns'
  params: {
    vnetId: network.outputs.vnetId
    tags: tags
  }
}

module privateEndpoints 'modules/privateEndpoints.bicep' = {
  name: 'private-endpoints'
  params: {
    location: location
    tags: tags
    peSubnetId: network.outputs.peSubnetId
    dnsZoneIds: privateDns.outputs.zoneIds
    keyVaultId: keyVault.outputs.id
    containerRegistryId: containerRegistry.outputs.id
  }
}

module containerAppsEnvironment 'modules/containerAppsEnv.bicep' = {
  name: 'container-apps-environment'
  params: {
    name: 'cae-${prefix}'
    location: location
    tags: tags
    infrastructureSubnetId: network.outputs.acaSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    internalOnly: true
  }
}

module frontDoor 'modules/frontDoorWaf.bicep' = if (deployFrontDoor && !empty(frontDoorOriginHostName)) {
  name: 'front-door'
  params: {
    profileName: frontDoorProfileName
    endpointName: frontDoorEndpointName
    wafPolicyName: frontDoorWafPolicyName
    originHostName: frontDoorOriginHostName
    tags: tags
  }
}

module postDeployVerify 'modules/postDeployVerify.bicep' = {
  name: 'post-deploy-verify'
  params: {
    name: 'ds-verify-${prefix}'
    location: location
    tags: tags
    userAssignedIdentityId: identity.outputs.appIdentityId
    keyVaultName: keyVault.outputs.name
    secretName: 'appinsights-connection-string'
  }
}

output projectPrefix string = prefix
output vnetName string = network.outputs.vnetName
output keyVaultName string = keyVault.outputs.name
output managedIdentityName string = identity.outputs.appIdentityName
output containerAppsEnvironmentName string = containerAppsEnvironment.outputs.environmentName
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output applicationInsightsConnectionStringSecretName string = 'appinsights-connection-string'
output acrName string = containerRegistry.outputs.name
output frontDoorProfileName string = deployFrontDoor ? frontDoor.?outputs.profileId ?? '' : ''
