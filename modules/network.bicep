// =============================================================================
// Virtual Network + Subnets
// =============================================================================
@description('Name of the virtual network.')
param name string

@description('Location for the resource.')
param location string

@description('Tags applied to the resource.')
param tags object

@description('Address space for the virtual network.')
param addressPrefix string = '10.20.0.0/16'

@description('Address prefix for the private endpoints subnet.')
param peSubnetPrefix string = '10.20.0.0/24'

@description('Address prefix for the Container Apps infrastructure subnet (min /23).')
param acaSubnetPrefix string = '10.20.2.0/23'

@description('Address prefix for the general workload subnet.')
param workloadSubnetPrefix string = '10.20.4.0/24'

var lateralTraversalRules = [
  {
    name: 'DenySshOutbound'
    properties: {
      access: 'Deny'
      direction: 'Outbound'
      priority: 4090
      protocol: 'Tcp'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: 'VirtualNetwork'
      destinationPortRange: '22'
    }
  }
  {
    name: 'DenyRdpOutbound'
    properties: {
      access: 'Deny'
      direction: 'Outbound'
      priority: 4091
      protocol: 'Tcp'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: 'VirtualNetwork'
      destinationPortRange: '3389'
    }
  }
]

resource privateEndpointsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-pep-${replace(name, 'vnet-', '')}'
  location: location
  tags: tags
  properties: {
    securityRules: lateralTraversalRules
  }
}

resource containerAppsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-aca-${replace(name, 'vnet-', '')}'
  location: location
  tags: tags
  properties: {
    securityRules: lateralTraversalRules
  }
}

resource applicationWorkloadsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-app-${replace(name, 'vnet-', '')}'
  location: location
  tags: tags
  properties: {
    securityRules: lateralTraversalRules
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-pep-${replace(name, 'vnet-', '')}'
        properties: {
          addressPrefix: peSubnetPrefix
          defaultOutboundAccess: false
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: privateEndpointsNsg.id
          }
        }
      }
      {
        name: 'snet-aca-${replace(name, 'vnet-', '')}'
        properties: {
          addressPrefix: acaSubnetPrefix
          networkSecurityGroup: {
            id: containerAppsNsg.id
          }
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-app-${replace(name, 'vnet-', '')}'
        properties: {
          addressPrefix: workloadSubnetPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: applicationWorkloadsNsg.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output peSubnetId string = vnet.properties.subnets[0].id
output acaSubnetId string = vnet.properties.subnets[1].id
output workloadSubnetId string = vnet.properties.subnets[2].id
