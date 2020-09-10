[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)][String]$Port,
    [Parameter(Mandatory=$False)][String]$Regex,
    [Parameter(Mandatory=$False)][String]$Glob,
    [Parameter(Mandatory=$True)][String]$VcpkgPath,
    [Parameter(Mandatory=$True)][String]$WorkDirectory,
    [Parameter(Mandatory=$False)][Switch]$DryRun,
    [Parameter(Mandatory=$False)][Switch]$Releases,
    [Parameter(Mandatory=$False)][Switch]$Tags,
    [Parameter(Mandatory=$False)][Switch]$Rolling,
    [Parameter(Mandatory=$False)][String]$PAT,
    [Parameter(Mandatory=$False)][String]$ReplaceTo,
    [Parameter(Mandatory=$False)][String]$ReplaceFrom,
    [Parameter(Mandatory=$False)][String]$SkipRelease,
    [Parameter(Mandatory=$False)][String]$FailingFrom
)

if (!$Releases -and !$Tags -and !$Rolling)
{
    throw "Must pass releases, tags, or rolling"
}

if (!(Test-Path "$VcpkgPath/.vcpkg-root"))
{
    throw "Could not find $VcpkgPath/.vcpkg-root"
}

$portdir = "$VcpkgPath/ports/$Port"
$portfile = "$portdir/portfile.cmake"
$portfile_contents = Get-Content $portfile -Raw
$controlfile = "$portdir/CONTROL"
if (Test-Path $controlfile)
{
    $controlfile_contents = Get-Content $controlfile -Raw

    if ($controlfile_contents -match "Version: +$FailingFrom\n")
    {
        "$Port not upgraded: upgrades marked as failing from $FailingFrom"
        return
    }
}
else
{
    $json_contents = Get-Content "$portdir/vcpkg.json" -Raw | ConvertFrom-Json
    if ($FailingFrom -and $json_contents."version-string" -match "$FailingFrom")
    {
        "$Port not upgraded: upgrades marked as failing from $FailingFrom"
        return
    }
}

$vcpkg_from_github_invokes = @($portfile_contents | select-string $(@("vcpkg_from_github\([^)]*",
"REPO +`"?([^)\s]+)[^)\S`"]+",
"REF +([^)\s]+)[^)\S]+",
"[^)]*\)") -join "") | % Matches)

if ($vcpkg_from_github_invokes.Count -eq 0)
{
    "$Port not upgraded: no call to vcpkg_from_github()"
    return
}

$repo = $vcpkg_from_github_invokes[0].Groups[1].Value -replace "`"",""
Write-Verbose "repo=$repo"
$oldtag = $vcpkg_from_github_invokes[0].Groups[2].Value -replace "`"",""
Write-Verbose "oldtag=$oldtag"

$workdirarg = "--git-dir=$WorkDirectory/$repo.git"

if (!(Test-Path "$WorkDirectory/$repo.git"))
{
    $out = git clone --bare https://github.com/$repo "$WorkDirectory/$repo.git"
    if (-not $?) { $out; throw }
}
else
{
    $out = $(git $workdirarg fetch --tags --prune 2>&1)
    if (-not $?) { $out; throw }
}

if ($Tags)
{
    Write-Verbose "git $workdirarg tag | ? { `$_ -match `"$Regex`" }"
    $alltags = $(git $workdirarg tag 2> $null) | ? { $_ -match $Regex }
    if ($alltags.length -eq 0)
    {
        "$Port has no matching tags for regex: $Regex"
        return
    }
    Write-Verbose "git $workdirarg rev-list $alltags --max-count=1"
    $latesttagsha = $(git $workdirarg rev-list $alltags --max-count=1 2> $null)
    if ($Glob)
    {
        $newtag = git $workdirarg describe --tags --abbrev=0 $latesttagsha --match=$Glob
    }
    else
    {
        $newtag = git $workdirarg describe --tags --abbrev=0 $latesttagsha
    }
}
else
{
    try
    {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if ($PAT)
        {
            $accessToken = "&access_token=$PAT"
        }
        else
        {
            $accessToken = ""
        }

        if ($Releases)
        {
            $doc = Invoke-WebRequest -Uri "https://api.github.com/repos/$repo/releases/latest$accessToken" -UseBasicParsing | ConvertFrom-Json
            $newtag = $doc | % tag_name
            if (!$newtag)
            {
                "$Port not upgraded: no releases"
                return
            }
        }
        else
        {
            $newtag = git $workdirarg rev-parse master
        }
        Write-Verbose "newtag=$newtag"
    }
    catch [System.Net.WebException]
    {
        "unable to fetch for $Port"
        return
    }
}

if (!$newtag)
{
    "$Port not upgraded: calculating newtag failed"
    return
}

if ($newtag -eq $SkipRelease)
{
    "$Port not upgraded: $newtag explicitly skipped"
    return
}

Write-Verbose "git $workdirarg rev-parse $newtag^`{commit`}"
$newtagcommit = git $workdirarg rev-parse $newtag^`{commit`}
Write-Verbose "git $workdirarg rev-parse $oldtag^`{commit`}"
$oldtagcommit = git $workdirarg rev-parse $oldtag^`{commit`}

if ($newtagcommit -ne $oldtagcommit)
{
    Write-Verbose "Replacing"
    $filename = $($repo -replace "/","-") + "-$newtagcommit.tar.gz"
    $downloaded_filename = "$VcpkgPath/downloads/$filename" -replace "\\","/"
    Write-Verbose "Archive path is $downloaded_filename"

    if (!(Test-Path "$VcpkgPath/downloads/$filename"))
    {
        Write-Verbose "Downloading"
        "file(DOWNLOAD `"https://github.com/$repo/archive/$newtagcommit.tar.gz`" `"$downloaded_filename`")" | out-file -enc ascii $WorkDirectory/temp.cmake
        cmake -P $WorkDirectory/temp.cmake
    }
    $sha = $(cmake -E sha512sum "$downloaded_filename") -replace " .*",""
    Write-Verbose "SHA512=$sha"

    $oldcall = $vcpkg_from_github_invokes[0].Groups[0].Value
    if ($Tags)
    {
        $newcall = $oldcall -replace "\sREF[^\n]+"," REF $newtagcommit # $newtag" -replace "SHA512[\s]+[^)\s]+","SHA512 $sha"
    }
    else
    {
        $newcall = $oldcall -replace "\sREF[^\n]+"," REF $newtagcommit" -replace "SHA512[\s]+[^)\s]+","SHA512 $sha"
    }
    Write-Verbose "oldcall is $oldcall"
    Write-Verbose "newcall is $newcall"
    $new_portfile_contents = $portfile_contents -replace [regex]::escape($oldcall),$newcall

    $libname = $repo -replace ".*/", ""
    Write-Verbose "libname is $libname"

    if ($Rolling)
    {
        $newtag_without_v = Get-Date -Format "yyyy-MM-dd"
    }
    else
    {
        $newtag_without_v = $newtag -replace "^v\.?([\.\d])","`$1" -replace "^$libname-","" -replace "^[rR]elease-","" -replace "^mysql-",""
        if ($ReplaceFrom)
        {
            $newtag_without_v = $newtag_without_v -replace $ReplaceFrom,$ReplaceTo
        }
    }
    Write-Verbose "processed newtag is $newtag_without_v"

    if (Test-Path $controlfile)
    {
        $newcontrol = $controlfile_contents -replace "\nVersion:[^\n]*","`nVersion: $newtag_without_v"
        if ($DryRun)
        {
            "# $portdir/CONTROL"
            $newcontrol
        }
        else
        {
            $newcontrol | Out-File "$portdir/CONTROL" -encoding Ascii -NoNewline
        }
    }
    else
    {
        $json_contents."version-string" = $newtag_without_v
        $json_contents.PSObject.Properties.Remove("port-version")
        ConvertTo-Json $json_contents | Out-File "$portdir/vcpkg.json" -encoding Ascii -NoNewline
        (& "$VcpkgPath/vcpkg" x-format-manifest "$portdir/vcpkg.json") | Out-Null
    }

    if($DryRun)
    {
        "# $portfile"
        $new_portfile_contents
    }
    else
    {
        $new_portfile_contents | Out-File $portfile -encoding Ascii -NoNewline
        "$Port upgraded: $oldtag -> $newtag"
    }
}
else
{
    "$Port is up-to-date: $oldtag -> $newtag"
}