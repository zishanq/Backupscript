######################################################################################################
#                                         	Script Start Here                                        #
######################################################################################################


param(

    [Parameter(Mandatory = $True)]
    [string] $TargetSubscription,

    [Parameter(Mandatory = $True)]
    [string] $TargetRgToBackup="",

    [Parameter(Mandatory = $False)]
    [string] $TargetAzureRegion="FranceCentral",

    [Parameter(Mandatory = $False)]
    [string] $LongCodeTag = "INFR",

    [Parameter(Mandatory = $False)]
    [string] $EnvTag = "DEV",

    [Parameter(Mandatory = $True)]
    [string] $TargetAzurePolicyName=""


    )

######################################################################################################
#                                         	Function log
######################################################################################################
function log
{

Param (
	[Parameter(Mandatory=$true,Position=1)]
	[STRING] $string,
	[Parameter(Mandatory=$false,Position=2)]
	[STRING] $color,
    [Parameter(Mandatory=$false,Position=3)]
	[STRING] $datelog
  
    )

#$date = (get-date).tostring('yyyyMMdd')
#$hour = (get-date).tostring('HHmmss')
[string]$logfilename = $datelog + "_configurebackup.log"
#[string]$path = (Get-Location)
[string]$pathlog = $logfilename

    if (!$Color) 
        {
            [string]$color = "white"
        }
    write-host $string -foregroundcolor $color
    (get-date -format yyyyMMdd_HHmmsstt).tostring()+":"+$string | out-file -Filepath $pathlog -Append   
}

######################################################################################################
#                                         	Main code : Creating the Backend Resource
######################################################################################################

#Get date
$dateexecution = (Get-Date -format yyyyMMdd_HHmmsstt).tostring()
#thash table for logging
[hashtable]$logging = @{}
#hash table for return
[hashtable]$return = @{}

log "########################################################################################### " green $dateexecution
log "starting script configurebackup.ps1...." green $dateexecution
log "########################################################################################### " green $dateexecution

#error variable clear
$Error.clear()

try
{

    #Recording inputs
    $logging.TargetSubscription = "TargetSubscription :  "+ $TargetSubscription
    $logging.TargetRgToBackup = "TargetRgToBackup:  "+ $TargetRgToBackup
    $logging.TargetAzureRegion = "TargetAzureRegion:  "+ $TargetAzureRegion
    $logging.TargetAzurePolicyName = "TargetAzurePolicyName:  "+ $TargetAzurePolicyName

    #Exporting inputs
    log "Input parameters" cyan $dateexecution
    log $logging.TargetSubscription cyan $dateexecution
    log $logging.TargetRgToBackup cyan $dateexecution
    log $logging.TargetAzureRegion cyan $dateexecution
    log $logging.TargetAzurePolicyName cyan $dateexecution

     #Selecting the subscription

    log "Selecting the subscription" green $dateexecution
    Select-AzSubscription -SubscriptionId $TargetSubscription -ErrorAction Stop | Out-Null
    $logging.TargetSubscription = "The target subscription is: "+$TargetSubscription
    log $logging.TargetSubscription green $dateexecution

    #Create a Recovery Services Vault and set its storage redundancy type


    [string]$TargetVaultName = ($LongCodeTag+"-"+$EnvTag+"-"+"RSV1").ToLower()
    $logging.TargetRsvName = "The target rsv is: "+$TargetVaultName
    log $logging.TargetRsvName green $dateexecution


    [string]$RgOfRsv=(Get-AzResourceGroup -Name $TargetRgToBackup).Location
   
    New-AzRecoveryServicesVault -ResourceGroupName $TargetRgToBackup -Name $TargetVaultName -Location $RgOfRsv
    
    
    #Set the Recovery Services Vault Redundancy to LRS


    $RsVaultRedundancy = Get-AzRecoveryServicesVault -Name $TargetVaultName
    Set-AzRecoveryServicesBackupProperties -Vault $RsVaultRedundancy -BackupStorageRedundancy LocallyRedundant

    $logging.TargetRsvName = "The target rsv is set with LRS parameter : "+$TargetVaultName
    log $logging.TargetRsvName green $dateexecution


    #Copy the name of the Recovery Services Vault & Policy

    Write-host "Copy the following name of the Recovery Vault :" $TargetVaultName -ForegroundColor yellow
    Write-host "Copy the following policy of the Recovery Vault :" $TargetAzurePolicyName -ForegroundColor yellow

    
    #Verification if the json files were be updated

    $Readhost = Read-Host 'Have you updated Json files ( y / n )'
    while ($Readhost -notmatch "y") {
        Write-host "You have to update the Json parameters files to continue"
        $Readhost = Read-Host 'Have you updated Json files ( y / n )'
    }

    $ReadPathJson = Read-Host 'Put the full Path of the Json File'
    $ReadPathParamJson = Read-Host 'Put the full Path of the Json Parameters File'


    #AutoUpdate the Path of TemplateFile & TemplateParameterFile parameters
    New-AzResourceGroupDeployment -Name ArmTemplateToAzure -ResourceGroupName $TargetRgToBackup `
        -TemplateFile $ReadPathJson `
        -TemplateParameterFile $ReadPathParamJson
  
    
    #Set the vault 

    $vault = Get-AzRecoveryServicesVault -ResourceGroupName $TargetRgToBackup -Name $TargetVaultName
    Set-AzRecoveryServicesVaultContext -Vault $vault


    #Get the list of all VMs in a Ressource Group

    $policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $TargetAzurePolicyName
    $listOfVms = Get-AzVM -ResourceGroupName $TargetRGToBackup
    [array]$listOfVmsName = $listOfVms.Name

    #Apply the Policy on all VMs of the Resource Group

    for($i=0; $i -lt  $listOfVms.count; $i++) {

    [string]$Vm = $listOfVmsName[$i]
    Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $TargetRGToBackup -Name $Vm -Policy $policy
    
    }
}


catch 

{

    log "An error occured" magenta $dateexecution
    
    [string]$result = '$false'
    $logging.error = "An error occured. " +$error[0]
    
    $logging.result = $result
    $return.error = $logging.error
    $return.result = $logging.result
    $logresult = "Script result :"+ $logging.result
    log  $logresult magenta $dateexecution
    log $logging.error magenta $dateexecution

}

return $return | Format-List
    
     