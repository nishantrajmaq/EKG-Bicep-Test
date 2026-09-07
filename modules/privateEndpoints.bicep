// =============================================================================
// Private Endpoints for platform services
// =============================================================================
@description('Location for the resources.')
param location string

@description('Tags applied to the resources.')
param tags object

@description('Subnet ID hosting the private endpoints.')
param peSubnetId string

@description('Map of private DNS zone IDs from the privateDns module.')
param dnsZoneIds object

param keyVaultId string

@description('Resource ID of the Azure Container Registry.')
param containerRegistryId string

@description('Create the ACR private endpoint. Private Link for ACR requires the Premium SKU.')
param deployContainerRegistryEndpoint bool = true

// ---- Key Vault ----
resource kvPe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pep-key-vault'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource kvDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: kvPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: dnsZoneIds.keyVault
        }
      }
    ]
  }
}

// ---- Azure Container Registry ----
resource acrPe 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployContainerRegistryEndpoint) {
  name: 'pep-container-registry'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'registry'
        properties: {
          privateLinkServiceId: containerRegistryId
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource acrDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployContainerRegistryEndpoint) {
  parent: acrPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'registry'
        properties: {
          privateDnsZoneId: dnsZoneIds.containerRegistry
        }
      }
    ]
  }
}

