param($eventGridEvent, $TriggerMetadata)

if ($eventGridEvent.data.policyRunStatus -eq "Succeeded") {

    $manifestUri = $eventGridEvent.data.manifestBlobUrl

    Write-Output "Manifest Uri: $manifestUri"

    Select-AzSubscription -Subscription $eventGridEvent.topic.Split("/")[2]

    $query = "resources | where type == 'microsoft.storage/storageaccounts' | where name == '$($eventGridEvent.data.accountName)' | project id"

    $result = Search-AzGraph -Query $query

    Write-Output $result.id
    Write-Output $eventGridEvent.data.accountName

    $ctx = (Get-AzStorageAccount -Name $eventGridEvent.data.accountName -ResourceGroupName $result.id.Split("/")[4]).Context

    try {
        Get-AzStorageBlobContent -Blob ($manifestUri -split "statistics/")[-1] -Container statistics -Destination "$env:TEMP\$($manifestUri.Split("/")[-1])" -Force -Context $ctx -ErrorAction Stop
    }
    catch {
        throw $_.Exception.Message
    }

    $manifestContent = Get-Content "$env:TEMP\$($manifestUri.Split("/")[-1])" | ConvertFrom-Json

    Remove-Item "$env:TEMP\$($manifestUri.Split("/")[-1])"

    foreach ($file in $manifestContent.files) {
        $eventArray = @()

        try {
            Get-AzStorageBlobContent -Blob $file.blob -Container $manifestContent.destinationContainer -Destination "$env:TEMP\$($file.blob.Split("/")[-1])" -Force -Context $ctx -ErrorAction Stop
        }
        catch {
            throw $_.Exception.Message
        }

        $stats = Import-Csv -Path "$env:TEMP\$($file.blob.Split("/")[-1])"

        Remove-Item "$env:TEMP\$($file.blob.Split("/")[-1])" -Force

        if ($stats.Count -ne 0) {
            $tiers = $stats | Select-Object -ExpandProperty AccessTier -Unique

            foreach ($tier in $tiers) {
                $event = @{}
                $event = @{
                    storageAccountName = $eventGridEvent.data.accountName
                    tier               = $tier
                    size               = ($stats | Where-Object AccessTier -eq $tier | Measure-Object -Sum -Property Content-Length).Sum
                    count              = ($stats | Where-Object AccessTier -eq $tier | Measure-Object).Count
                }
    
                $eventArray += $event
            }
    
            $req = Post-LogAnalyticsData -customerId $env:WorkspaceId -sharedKey $env:WorkspaceKey -body ($eventArray | ConvertTo-Json) -logType "AccessTierStatistics"
    
            if ($req -ne 200) {
                throw "An error occured sending to the Log Analytics workspace"
            }
        }        
    }
}
