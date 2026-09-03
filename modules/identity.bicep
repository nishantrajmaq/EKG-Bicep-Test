// =============================================================================
// User-Assigned Managed Identities
// =============================================================================
@description('Prefix used for identity names.')
param namePrefix string

@description('Location for the resources.')
param location string

@description('Tags applied to the resources.')
param tags object

// Shared identity for application workloads and future data-plane access.
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uami-${namePrefix}'
  location: location
  tags: tags
}

output appIdentityId string = appIdentity.id
output appIdentityName string = appIdentity.name
output appIdentityPrincipalId string = appIdentity.properties.principalId
output appIdentityClientId string = appIdentity.properties.clientId

