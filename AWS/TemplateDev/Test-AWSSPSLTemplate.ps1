﻿# Test-AWSSPSLTemplate.ps1
# 
# Example call: 
#   .\Test-AWSSPSLTemplate.ps1 -Regions us-east-1 -AMIType BYOL -Branch test -StackName HAC-TEST -Verbose
#
# Notes:
#   

[CmdletBinding()]
Param(
    [string]   $ParameterFilePath = $Null,
    [string]   $StackName = "SPSL",
    [string]   $TemplateURLBase = "https://s3.amazonaws.com/quickstart-sios-protection-suite",
    [string]   $AMIType = "BYOL",
    [string]   $SIOSLicenseKeyFtpURL = "http://ftp.us.sios.com/pickup/EVAL_Joe_User_joeuser_2020-01-27_SPSLinux/",
    [string[]] $Regions = @("us-east-1"),
    [string]   $Branch = $Null,
    [string]   $Profile = $Null
)

if ($Regions -like "all") {
    $Regions = @("us-east-1","us-east-2","us-west-1","us-west-2","ca-central-1","ap-south-1","ap-northeast-2","ap-southeast-1","ap-southeast-2","eu-central-1","eu-north-1","eu-west-1","eu-west-2","eu-west-3","sa-east-1")
}

function Get-ParametersFromURL() {
    Param(
        [Parameter(Mandatory=$False,Position=0)]
        [string] $URL
    )
    
    return Invoke-WebRequest -Uri $URL | ConvertFrom-Json
}

function Get-ParametersFromFile() {
    Param(
        [Parameter(Mandatory=$False,Position=0)]
        [string] $Path
    )
    
    return Get-Content $Path | Out-String | ConvertFrom-Json
}

if ($Branch) {
    $TemplateURLBase += "/$Branch"
} else {
    $TemplateURLBase += "/test"
}

if (-Not $ParameterFilePath) {
    # the payg file contains the same thing as the byol one, except for fixes made below based on param values
    # so we can currently use the payg file as a base
    $ParameterFilePath = $TemplateURLBase + "/ci/payg.json"
    $parameters = [System.Collections.ArrayList] (Get-ParametersFromURL -URL $ParameterFilePath)
} else {
    $parameters = [System.Collections.ArrayList] (Get-ParametersFromFile -Path "$ParameterFilePath\\sios-protection-suite-master-parameters$Branch.json")
}

if( -Not $parameters ) {
    Write-Host "Failed to parse parameters"
    exit 1
} else {
    Write-Verbose "Parameters parsed successfully"
}

if( $AMIType -Like "BYOL" -AND $SIOSLicenseKeyFtpURL ) {
    ($parameters | Where-Object -Property ParameterKey -like SIOSLicenseKeyFtpURL).ParameterValue = $SIOSLicenseKeyFtpURL
}

($parameters | Where-Object -Property ParameterKey -like NewRootPassword).ParameterValue = "SIOS!5105"
($parameters | Where-Object -Property ParameterKey -like KeyPairName).ParameterValue = "AUTOMATION"
($parameters | Where-Object -Property ParameterKey -like SIOSAMIType).ParameterValue = $AMIType

$parameters.Add([PSCustomObject]@{
    ParameterKey = "QSS3BucketName"
    ParameterValue = "quickstart-sios-protection-suite"
}) > $Null

if($Branch) {
    $parameters.Add([PSCustomObject]@{
        ParameterKey = "QSS3KeyPrefix"
        ParameterValue = "$Branch/"
    }) > $Null
} else {
    $parameters.Add([PSCustomObject]@{
        ParameterKey = "QSS3KeyPrefix"
        ParameterValue = "test/"
    }) > $Null
}

$masterStacks = [ordered]@{}

foreach ($region in $Regions) {
    ($parameters | Where-Object -Property ParameterKey -like AvailabilityZones).ParameterValue = $region+"a,"+$region+"b"
    $parameters | Format-Table | Out-String -Stream | Write-Verbose
    if($Profile) {
        $masterStacks.Add($region,(New-CFNStack -Stackname $StackName -TemplateURL "$TemplateURLBase/templates/sios-protection-suite-master.template" -Parameters $parameters -Region $region -Capabilities CAPABILITY_IAM -DisableRollback $True -ProfileName $Profile))
    } else {
        $masterStacks.Add($region,(New-CFNStack -Stackname $StackName -TemplateURL "$TemplateURLBase/templates/sios-protection-suite-master.template" -Parameters $parameters -Region $region -Capabilities CAPABILITY_IAM -DisableRollback $True))
    }
}

# $jobHT = [ordered]@{}
# foreach ($region in $Regions) {
#     $jobHT.Add($region, (Start-Job -FilePath .\Test-AWSDKCETemplateWorker.ps1 -ArgumentList $region,($masterStacks[$region]),$ParameterFilePath,$TemplateURLBase,$parameters))
# }

return $masterStacks

#$parameters = Get-ParametersFromFile -Path "C:\Users\hcarroll.STEELEYE\DKCE-DK$DKServerVersion-$DKLicenseModel-SQL$SQLServerVersion.json"
#$stack = New-CFNStack -Stackname "SPSL" -TemplateURL $TemplateURL -Parameters $Parameters
