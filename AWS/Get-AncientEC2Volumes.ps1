# Get-AncientEC2Volumes.ps1
#
# Example 1:
# .\Get-AncientEC2Volumes.ps1 -Region us-east-1 -Profile currentgen -ToDelete -Verbose
#
# Example 2:
# $profiles = @("automation","currentgen","dev","ps","qa","support","ts")
# $toDelete = [ordered]@{}
# foreach ($profile in $profiles) {
#     $del = .\Get-AncientEC2Volumes.ps1 -Profile $profile -ToDelete
#     $toDelete.Add($profile,$del)
# }

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string] $Profile = $Null,

    [Parameter(Mandatory=$False)]
    [string[]] $Regions = $Null,

    [Parameter(Mandatory=$False)]
    [switch] $ToDelete,

    [Parameter(Mandatory=$False)]
    [switch] $ToKeep
)

if ($Regions -eq $Null) {
    $TargetRegions = (&"aws" ec2 describe-regions --profile $Profile --region us-east-1 --output json | ConvertFrom-Json).Regions.RegionName
} else {
    $TargetRegions = $Regions
}

Write-Verbose ("Scanning " + $TargetRegions.Count + " regions.")
$keep = [System.Collections.ArrayList]@()
$delete = [System.Collections.ArrayList]@()
$volumes = [System.Collections.ArrayList]@()
foreach ($region in $TargetRegions) {
    $vols = Get-EC2Volume -Region $region -ProfileName $Profile
    Write-Verbose $volumes.Count

    $today = Get-Date
    $vols | % {
        if($_.Attachments.Count -eq 0) {
            if($today -lt $_.CreateTime.AddMonths(6)) {
                $delete.Add($_) > $Null
            }
        }
        else {
            $keep.Add($_) > $Null
        }
        $volumes.Add($_) > $Null
    }
}
if($ToDelete) {
    return $delete
}
if($ToKeep) {
    return $keep
}
return $volumes
# END
