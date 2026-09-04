# EKG Platform Initial Deployment

This solution deploys the first EKG Platform infrastructure milestone into an existing Azure resource group. It does not create the resource group and does not deploy the later data, AI, or application workloads.

## Contents

```text
main.bicep                          Main resource-group-scoped template
main.bicepparam                     Deployment parameters
bicepconfig.json                    Bicep configuration and Graph extension
modules/                            Referenced deployment modules
```

## Resources Deployed

| Resource | Implementation | Purpose |
|---|---|---|
| User-assigned managed identity | `modules/identity.bicep` | Shared application identity for current and later milestones |
| Virtual network | `modules/network.bicep` | `10.20.0.0/16` platform network |
| Subnets and NSGs | `modules/network.bicep` | Purpose-specific subnets with attached NSGs |
| Key Vault | `modules/keyvault.bicep` | RBAC-enabled, private-only secret store |
| Key Vault RBAC assignments | `modules/keyvault.bicep` | Secrets User for the app identity and optional Administrator |
| Key Vault diagnostics | `modules/keyvault.bicep` | Audit logs and metrics sent to Log Analytics |
| Private DNS zones | `modules/privateDns.bicep` | Private name resolution linked to the VNet |
| Private endpoints | `modules/privateEndpoints.bicep` | Key Vault and ACR private access |
| Log Analytics workspace | `modules/monitoring.bicep` | Central log collection |
| Application Insights | `modules/monitoring.bicep` | Workspace-based application monitoring |
| Action Group | `modules/monitoring.bicep` | Alert notification target; email receivers are currently empty |
| Azure Container Registry | Direct resource in the main template | Standard registry with admin credentials disabled |
| Container Apps environment | `modules/containerAppsEnv.bicep` | Internal, VNet-integrated environment for later applications |
| Entra ID app registrations | `modules/entraApps.bicep` | Optional API and client applications |
| Front Door Premium and WAF | `modules/frontDoorWaf.bicep` | Optional; enabled only with an origin hostname |

The Application Insights connection string is stored in Key Vault as `appinsights-connection-string`. It is not exposed as a deployment output.

## Subnets

| Subnet | Address range | Intended use |
|---|---:|---|
| `snet-pep-ekg-test-eus` | `10.20.0.0/24` | Private endpoints for Key Vault, ACR, and future private services |
| `snet-aca-ekg-test-eus` | `10.20.2.0/23` | Delegated to `Microsoft.App/environments` |
| `snet-app-ekg-test-eus` | `10.20.4.0/24` | Reserved for future application workloads |

Attached NSGs are `nsg-pep-ekg-test-eus`, `nsg-aca-ekg-test-eus`, and `nsg-app-ekg-test-eus`. They currently use Azure default rules.

Azure AI Search and AI Foundry are PaaS resources and are not placed directly inside a subnet. Their future private endpoints should use `snet-private-endpoints`.

## Naming Convention

The base prefix is:

```text
{projectName}-{environmentName}-{regionCode}
```

For the default parameter values, the prefix is `ekg-test-eus`.

| Resource | Name pattern | Example |
|---|---|---|
| Virtual network | `vnet-{prefix}` | `vnet-ekg-test-eus` |
| Key Vault | `kv-{prefix}` | `kv-ekg-test-eus` |
| Log Analytics | `log-{prefix}` | `log-ekg-test-eus` |
| Application Insights | `appi-{prefix}` | `appi-ekg-test-eus` |
| Action Group | `ag-{prefix}` | `ag-ekg-test-eus` |
| User-assigned managed identity | `uami-{prefix}` | `uami-ekg-test-eus` |
| Container Apps environment | `cae-{prefix}` | `cae-ekg-test-eus` |
| Container Registry | `acr{projectName}{environmentName}{regionCode}` | `acrekgtesteus` |
| Key Vault private endpoint | Fixed purpose name | `pep-key-vault` |
| ACR private endpoint | Fixed purpose name | `pep-container-registry` |
| Private DNS zones | Azure private-link zone names | `privatelink.vaultcore.azure.net`, `privatelink.azurecr.io` |
| NSGs | `nsg-{purpose}-{prefix}` | `nsg-app-ekg-test-eus` |
| Front Door profile | `afd-{prefix}` | `afd-ekg-test-eus` |
| Front Door endpoint | `afde{projectName}{environmentName}{regionCode}` | `afdekgtesteus` |
| WAF policy | `waf-{prefix}` | `waf-ekg-test-eus` |

With the default values, the actual Container Registry name is `acrekgtesteus`.

## Prerequisites

- Azure CLI installed and authenticated with `az login`.
- Bicep support available through Azure CLI. Install it with `az bicep install` if required.
- Existing resource group: `rg-ekg-test-eus`.
- Permission to deploy resources and role assignments in that resource group.
- Permission to assign Key Vault roles to the managed identity.
- For optional Entra app registrations, sufficient Microsoft Graph/Entra permissions such as Application Administrator.
- For optional Front Door/WAF, provide a reachable HTTPS origin hostname.
- The deployment must be run from a network path that can reach the private Key Vault when retrieving secrets.

## Configure Parameters

The current parameter file contains:

| Parameter | Current value |
|---|---|
| `projectName` | `ekg` |
| `environmentName` | `test` |
| `location` | `eastus` |
| `adminPrincipalId` | Empty, so the optional admin role and Entra app module are skipped |
| `deployFrontDoor` | `false` |
| `frontDoorOriginHostName` | Empty; required when Front Door is enabled |
| `acrReplicaLocations` | `['westus2']` |
| `logAnalyticsReplicaLocation` | `centralus` |

Set `adminPrincipalId` to the object ID of an administrator when the deployment should create the Key Vault Administrator assignment. Do not use an application client ID in this field.
Set the replica locations to regions appropriate for the deployment's Azure region pair.

## Validate and Deploy

Run these commands from the solution directory:

```powershell
az login
az account set --subscription "<subscription-id>"
az group show --name rg-ekg-test-eus

az deployment group validate `
  --resource-group rg-ekg-test-eus `
  --name initial-deploy-validation `
  --template-file main.bicep `
  --parameters @main.bicepparam

az deployment group what-if `
  --resource-group rg-ekg-test-eus `
  --name initial-deploy-what-if `
  --template-file main.bicep `
  --parameters @main.bicepparam

az deployment group create `
  --resource-group rg-ekg-test-eus `
  --name initial-deploy-deploy `
  --template-file main.bicep `
  --parameters @main.bicepparam
```

To build the template locally:

```powershell
az bicep build --file main.bicep
```

## Verify Deployment

```powershell
az resource list `
  --resource-group rg-ekg-test-eus `
  --output table

az network vnet subnet list `
  --resource-group rg-ekg-test-eus `
  --vnet-name vnet-ekg-test-eus `
  --output table

az deployment group show `
  --resource-group rg-ekg-test-eus `
  --name initial-deploy-deploy `
  --query properties.provisioningState `
  --output tsv
```

## Read the Application Insights Secret

The Key Vault module creates the secret `appinsights-connection-string`. Because the vault is private, the command must run from an approved network location:

```powershell
az keyvault secret show `
  --vault-name kv-ekg-test-eus `
  --name appinsights-connection-string `
  --query value `
  --output tsv
```

The application managed identity receives the Key Vault Secrets User role. A human operator needs an appropriate Key Vault data-plane role, such as Key Vault Administrator or Key Vault Secrets User, to read the secret.

## Scope and Future Milestones

This template intentionally excludes Storage, Cosmos DB, Azure AI Search, Azure OpenAI, AI Foundry, and application containers. Their future private endpoints can reuse `snet-pep-ekg-test-eus`; future workloads can use `snet-app-ekg-test-eus` or the Container Apps infrastructure subnet according to each service's requirements.

Front Door Premium and its WAF policy are available conditionally. Set `deployFrontDoor` to `true` and provide an HTTPS `frontDoorOriginHostName`. Container Apps do not require a private endpoint because an internal Container Apps environment is VNet-integrated.

## Tags

Resources receive these governance tags:

```text
environment: {environmentName}
managedBy: bicep
company: MAQ Software
createdBy: nishantr@maqsoftware.com
```
