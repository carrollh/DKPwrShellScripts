﻿# Get-SSMDocumentSteps.ps1
# 
# Example usage:
#   PS> .\Get-SSMDocumentSteps.ps1 -StackName SIOSStack -Profile currentgen
#   PS> .\Get-SSMDocumentSteps.ps1 -Profile currentgen
#

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string] $StackName = "",

    [Parameter(Mandatory=$True)]
    [string] $Region = "",

    [Parameter(Mandatory=$False)]
    [string] $Profile = "",

    [Parameter(Mandatory=$False)]
    [Switch] $AllSteps
)

$steps, $executionId, $ssm, $step, $doc = $Null

if($Profile -ne "") {
    $ssm = & "aws" ssm describe-automation-executions --region $Region --profile $Profile | convertfrom-json
}
else {
    $ssm = & "aws" ssm describe-automation-executions --region $Region | convertfrom-json
}

$ssm.AutomationExecutionMetadataList | % {
    if($_.DocumentName -like "$StackName*") {
        $doc = $_
    } 
}
if(-Not $doc) {
    Write-Host "SSM Document not found. Try again later."
    return
}

$executionId = $doc.AutomationExecutionId

if($Profile -ne "") {
    $results = & "aws" ssm get-automation-execution --automation-execution-id $executionId --region $Region --profile $Profile | convertfrom-json
}
else {
    $results = & "aws" ssm get-automation-execution --automation-execution-id $executionId --region $Region | convertfrom-json
}

$steps = $results.AutomationExecution.StepExecutions

if($AllSteps) {
    $steps
}

$step = $steps | Where-Object -Property StepStatus -like "Failed"
if($step) {
    Write-Host "FAILURE"
}
else {
    $step = $steps | Where-Object -Property StepStatus -like "InProgress"
    Write-Host "IN PROGRESS"
}

$ssm.AutomationExecutionMetadataList | Where-Object -Property DocumentName -like "$StackName*"

if($step) {
   return $step 
}
else {
   Write-Host "SUCCESS"
   return
}