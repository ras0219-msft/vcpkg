[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)][String]$VcpkgPath
)

if (!(Test-Path "$VcpkgPath/.vcpkg-root"))
{
    throw "Could not find $VcpkgPath/.vcpkg-root"
}

$utilsdir = split-path -parent $script:MyInvocation.MyCommand.Definition

# import $allPorts
. "$utilsdir/portData.ps1"

$githubPorts = git -C $VcpkgPath\ports grep -l "vcpkg_from_github" -- $VcpkgPath\ports\`*\portfile.cmake `
 | % { $_ -replace "/.*","" }


$githubPortsSet = @{}

$githubPorts | % {
    $githubPortsSet[$_] = $true
}

$allPorts | % {
    if ($_.GetType() -eq [String]) { $githubPortsSet.Remove($_) }
    else { $githubPortsSet.Remove($_.port) }
}

$portTable = $githubPortsSet.Keys | Sort | % {
    if (Test-Path $VcpkgPath\ports\$_\CONTROL) {
        $version = $(gc $VcpkgPath\ports\$_\CONTROL | ? { $_ -match "^Version:" } | % { $_ -replace "Version: ?","" })
        if ($version -match "^\d\d\d\d-\d\d-\d\d") { $type = "date" }
        elseif ($version -match "^[0-9a-zA-Z]{5,}-?\d?$") { $type = "commit" }
        else { $type = "tag" }
    } else {
        $version = $(gc $VcpkgPath\ports\$_\vcpkg.json | ConvertFrom-Json)."version-string"
        if ($version -match "^\d\d\d\d-\d\d-\d\d") { $type = "date" }
        elseif ($version -match "^[0-9a-zA-Z]{5,}-?\d?$") { $type = "commit" }
        else { $type = "tag" }
    }

    [PSCustomObject]@{
        "port" = $_;
        "version" = $version;
        "type" = $type
    }
}

$portTable
