// =============================================================================
// Private DNS Zones + VNet Links
// =============================================================================
@description('Resource ID of the virtual network to link.')
param vnetId string

@description('Tags applied to the resources.')
param tags object

var zoneNames = {
  keyVault: 'privatelink.vaultcore.azure.net'
  blob: 'privatelink.blob.${environment().suffixes.storage}'
  cosmos: 'privatelink.documents.azure.com'
  search: 'privatelink.search.windows.net'
  openai: 'privatelink.openai.azure.com'
  cognitiveServices: 'privatelink.cognitiveservices.azure.com'
  aiServices: 'privatelink.services.ai.azure.com'
}

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for name in items(zoneNames): {
    name: name.value
    location: 'global'
    tags: tags
  }
]

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (name, i) in items(zoneNames): {
    parent: zones[i]
    name: 'link-${name.key}'
    location: 'global'
    tags: tags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnetId
      }
    }
  }
]

// NOTE: items() returns entries sorted alphabetically by key; the output map
// below must remain aligned with that order.
output zoneIds object = {
  aiServices: zones[0].id
  blob: zones[1].id
  cognitiveServices: zones[2].id
  cosmos: zones[3].id
  keyVault: zones[4].id
  openai: zones[5].id
  search: zones[6].id
}
