// =============================================================================
// Entra App Registrations (Microsoft Graph Bicep extension)
//
// Requires the Microsoft Graph extension declared in bicepconfig.json and a
// deploying principal with sufficient Entra permissions (e.g. Application
// Administrator) plus Microsoft Graph API permissions (Application.ReadWrite.All).
// Microsoft.Graph resources are TENANT-scoped, not resource-group scoped.
// =============================================================================
extension microsoftGraphV1

@description('Prefix used for application display names.')
param namePrefix string

// API / backend application registration.
resource apiApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: 'app-api-${namePrefix}'
  uniqueName: 'app-api-${namePrefix}'
  signInAudience: 'AzureADMyOrg'
  api: {
    requestedAccessTokenVersion: 2
  }
}

resource apiAppSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: apiApp.appId
}

// Client / frontend application registration.
resource clientApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: 'app-client-${namePrefix}'
  uniqueName: 'app-client-${namePrefix}'
  signInAudience: 'AzureADMyOrg'
  publicClient: {
    redirectUris: [
      'http://localhost'
    ]
  }
}

resource clientAppSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: clientApp.appId
}

output apiAppId string = apiApp.appId
output apiAppObjectId string = apiApp.id
output apiServicePrincipalId string = apiAppSp.id
output clientAppId string = clientApp.appId
output clientAppObjectId string = clientApp.id
output clientServicePrincipalId string = clientAppSp.id
