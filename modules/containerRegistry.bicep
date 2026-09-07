// Azure Container Registry with optional geo-replication.
@description('Container Registry name (globally unique, 5-50 alphanumeric).')
@minLength(5)
@maxLength(50)
param name string

@description('Location for the resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Registry SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Standard'

@description('Additional Azure regions for geo-replication (Premium SKU only).')
param replicaLocations array = []

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    // Disabling public access (Private Link) is only supported on Premium SKU.
    publicNetworkAccess: sku == 'Premium' ? 'Disabled' : 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

// Replications require Premium SKU; skipped for Standard.
resource replications 'Microsoft.ContainerRegistry/registries/replications@2023-07-01' = [for replicaLocation in replicaLocations: if (sku == 'Premium') {
  parent: registry
  name: 'rep${toLower(replace(replace(replicaLocation, ' ', ''), '-', ''))}'
  location: replicaLocation
  properties: {
    regionEndpointEnabled: true
  }
}]

output id string = registry.id
output name string = registry.name
output loginServer string = registry.properties.loginServer
