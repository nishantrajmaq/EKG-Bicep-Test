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

