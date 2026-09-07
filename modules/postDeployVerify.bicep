// Post-deployment verification script.
@description('Name of the deployment script resource.')
param name string

@description('Location for the resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Resource ID of the user-assigned managed identity used to run the script.')
param userAssignedIdentityId string

@description('Key Vault name to verify.')
param keyVaultName string

@description('Secret name expected to exist in the Key Vault.')
param secretName string

resource verify 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    retentionInterval: 'PT1H'
    timeout: 'PT10M'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'KV_NAME'
        value: keyVaultName
      }
      {
        name: 'SECRET_NAME'
        value: secretName
      }
    ]
    scriptContent: '''
      set -eu
      echo "Verifying Key Vault $KV_NAME and secret $SECRET_NAME..."
      az keyvault show --name "$KV_NAME" --query "properties.provisioningState" -o tsv
      az keyvault secret show --vault-name "$KV_NAME" --name "$SECRET_NAME" --query "id" -o tsv
      echo "Verification passed."
    '''
  }
}

output scriptId string = verify.id
