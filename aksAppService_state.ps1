<#
    .SYNOPSIS
        This Azure Automation runbook automates the scheduled shutdown and startup of AKS Clusters & App services in an Azure subscription. 

    .DESCRIPTION
        This is a PowerShell runbook, Make sure that automation managed identity has the required permissions to start and stop the AKS Cluster and App services.
        This runbook uses ntfy.sh to send notifications to your phone. Make sure to update topic url accordingly

    .PARAMETER ResourceGroupName
        The name of the ResourceGroup where the AKS Cluster is located
    
    .PARAMETER AksClusterName
        The name of the AKS Cluster to
    
    .PARAMETER Choice
        Currently supported operations are 'start' and 'stop'
    
    .PARAMETER subscriptioName
        The name of the subscription where the AKS Cluster & App services are located

    .PARAMETER topicName
        The name of the topic to send notifications to your phone

    .OUTPUTS
        Notification on your phone :).
#>

Param(
    [parameter(Mandatory = $true)]
    [String] $ResourceGroupName,
    [parameter(Mandatory = $true)]
    [String] $AksClusterName,
    [parameter(Mandatory = $true)]
    [String] $subscriptioName,
    [parameter(Mandatory = $true)]
    [String] $choice,
    [parameter(Mandatory = $true)]
    [String] $topicName

)

Write-Output "Logging into Azure using System Managed Identity"
$AzureContext = (Connect-AzAccount -Identity).context
$AzureContext = Set-AzContext -SubscriptionName $subscriptioName -DefaultProfile $AzureContext

Write-Host "Az Account Context Output"  
$AzureContext | Format-List * 

function pauseCluster {
    Write-Output "Stopping your AKS Cluster"
    Stop-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $AksClusterName 2>$null
}

function startCluster {
    Write-Output "Starting your AKS Cluster"
    Start-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $AksClusterName 2>$null
}

function notification {
    param (
        [string]$message
    )
    $uri = "https://ntfy.sh/$topicName"
    Invoke-RestMethod -Uri $uri -Method Post -Body $message 2>$null
}

$runningState = "Running"

$website_Processings_Running = Get-AzWebApp -ResourceGroupName $ResourceGroupName | where-object -FilterScript { $_.state -eq $runningState }

$pausedState = "Stopped"
$website_Processings_Paused = Get-AzWebApp -ResourceGroupName $ResourceGroupName | where-object -FilterScript { $_.state -eq $pausedState }


# shows notification for running web apps
foreach ($website_Processing In $website_Processings_Running) {
    $result = Stop-AzWebApp -ResourceGroupName $ResourceGroupName -Name $website_Processing.Name
    if ($result) {
        Write-Output "- $($website_Processing.Name) shutdown successfully"
        notification -message "$($website_Processing.Name) shutdown successful."
    }
    else {
        Write-Output "Something went wrong, contact Amit Gujar during 10:00 - 19:00"
    }
}

# shows notification for already paused web apps
foreach ($website_Processing In $website_Processings_Paused) {
    Start-AzWebApp -ResourceGroupName $ResourceGroupName -Name $website_Processing.Name
    Write-Output "- $($website_Processing.Name) already paused"
    notification -message "$($website_Processing.Name) already paused."
}

# here goes your aks cluster :)
switch ($choice) {
    'start' {
        Write-Output "Starting Cluster $AksClusterName in $ResourceGroupName"
        startCluster
    }
    'stop' {
        Write-Output "Stopping Cluster $AksClusterName in $ResourceGroupName"
        pauseCluster
    }
}
