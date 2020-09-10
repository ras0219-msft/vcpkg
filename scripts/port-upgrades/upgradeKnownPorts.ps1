[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)][String]$VcpkgPath,
    [Parameter(Mandatory=$True)][String]$WorkDirectory,
    [Parameter(Mandatory=$False)][Switch]$NoTags,
    [Parameter(Mandatory=$False)][Switch]$NoRolling,
    [Parameter(Mandatory=$False)][String]$Filter,
    [Parameter(Mandatory=$False)][Switch]$ForceFailing
)

if (!(Test-Path "$VcpkgPath/.vcpkg-root"))
{
    throw "Could not find $VcpkgPath/.vcpkg-root"
}

$utilsdir = split-path -parent $script:MyInvocation.MyCommand.Definition

# import $allPorts
. "$utilsdir/portData.ps1"

$allPorts | % {
    if ($_.GetType() -eq [String])
    {
        # Tag-based
        if (!$NoTags -and (-not $Filter -or $_ -match $Filter))
        {
            Write-Verbose "Handling $_"
            & "$utilsdir/upgradePort.ps1" -VcpkgPath $VcpkgPath -WorkDirectory $WorkDirectory -Port $_ -Tags
        }
    }
    elseif ($Filter -and $_.port -notmatch $Filter)
    {
        # Skipped due to filter
    }
    elseif ($_.disabled)
    {
        # Disabled tombstone
    }
    elseif ($_.rolling)
    {
        # Rolling release
        if (!$NoRolling)
        {
            Write-Verbose "Handling $_"
            & "$utilsdir/upgradePort.ps1" -VcpkgPath $VcpkgPath -WorkDirectory $WorkDirectory -Port $_.port -Rolling
        }
    }
    else
    {
        # Tag-based with regex filter
        if (!$NoTags)
        {
            if ($ForceFailing) { $failingFrom = "" }
            else { $failingFrom = $_.failingFrom }

            Write-Verbose "Handling $_"

            & "$utilsdir/upgradePort.ps1" `
                -VcpkgPath $VcpkgPath `
                -WorkDirectory $WorkDirectory `
                -Port $_.port `
                -Regex $_.regex `
                -Tags `
                -Glob $_.glob `
                -ReplaceFrom $_.replaceFrom `
                -ReplaceTo $_.replaceTo `
                -SkipRelease $_.skipRelease `
                -FailingFrom $failingFrom
        }
    }
}
