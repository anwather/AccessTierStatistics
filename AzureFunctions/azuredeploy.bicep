param deploymentLocation string = resourceGroup().location
param appInsightsName string
param appServicePlanName string
param azureFunctionName string
param azureFunctionStorageAccountName string
param LogAnalyticWorkspaceResourceId string

resource asp 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: deploymentLocation
  kind: 'functionapp'
  sku: {
    name: 'Y1'
  }
}

resource st 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: azureFunctionStorageAccountName
  location: deploymentLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource functionApp 'microsoft.insights/components@2015-05-01' = {
  name: appInsightsName
  location: deploymentLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

resource function 'Microsoft.Web/sites@2022-03-01' = {
  name: azureFunctionName
  identity: {
    type: 'SystemAssigned'
  }
  location: deploymentLocation
  kind: 'functionapp'
  properties: {
    enabled: true
    httpsOnly: true
    siteConfig: {
      ftpsState: 'Disabled'
      powerShellVersion: '7.2'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference('microsoft.insights/components/${appInsightsName}', '2015-05-01').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: reference('microsoft.insights/components/${appInsightsName}', '2015-05-01').ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${st.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(st.id, st.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${st.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(st.id, st.apiVersion).keys[0].value}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'LogAnalyticWorkspaceResourceId'
          value: LogAnalyticWorkspaceResourceId
        }
      ]
    }
  }
}

output principalId string = function.identity.principalId
output functionResourceId string = function.id
