using './main.bicep'

param projectName = 'ekg'
param environmentName = 'test'
param location = 'eastus2'
param adminPrincipalId = ''
param deployFrontDoor = false
param frontDoorOriginHostName = ''
param acrReplicaLocations = []
param logAnalyticsReplicaLocation = ''
