$resourceGroupName = "access-tier-statistics" # Update this value
$appServicePlanName = "ats-asp-aue" # Update this value
$deploymentRegion = "australiaeast" # Update this value
$appInsightsName = "ast-01" # Update this value
$azureFunctionName = "accesstierstatistics" # Update this value
$azureFunctionStorageAccountName = "" # Update this value
$LogAnalyticWorkspaceResourceId = "" # Update this value

New-AzResourceGroup -Name $resourceGroupName -Location $deploymentRegion -Force

$params = @{
    appServicePlanName              = $appServicePlanName
    azureFunctionName               = $azureFunctionName
    azureFunctionStorageAccountName = $azureFunctionStorageAccountName
    LogAnalyticWorkspaceResourceId  = $LogAnalyticWorkspaceResourceId
    appInsightsName                 = $appInsightsName
}

$output = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.bicep -Verbose @params

$currentSub = (Get-AzContext).Subscription.Id

Select-AzSubscription -Subscription $LogAnalyticWorkspaceResourceId.Split("/")[2]

New-AzRoleAssignment -ObjectId $output.Outputs.principalId.Value -RoleDefinitionName 'Log Analytics Contributor' -Scope $LogAnalyticWorkspaceResourceId

Select-AzSubscription -Subscription $currentSub

Compress-Archive -Path .\AccessTierStatistics\* -DestinationPath .\AccessTierStatistics.zip -Force

Publish-AzWebApp -ArchivePath .\AccessTierStatistics.zip -ResourceGroupName $resourceGroupName -Name $azureFunctionName -Verbose -Force

