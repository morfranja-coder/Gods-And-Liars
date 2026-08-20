param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Addons = Join-Path $Root "addons"
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) "gods-and-liars-tools"

$GdUnitVersion = "v6.2.0"
$StateChartsVersion = "v0.22.5"

function Install-GitHubAddon {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Repository,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$AddonPath,
        [Parameter(Mandatory = $true)][string]$DestinationName
    )

    $Destination = Join-Path $Addons $DestinationName
    if ((Test-Path $Destination) -and -not $Force) {
        Write-Host "[skip] $Name already exists at $Destination"
        return
    }

    $Work = Join-Path $Temp $DestinationName
    $Zip = Join-Path $Work "source.zip"
    $Expanded = Join-Path $Work "expanded"

    if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
    New-Item -ItemType Directory -Path $Expanded -Force | Out-Null

    $Url = "https://github.com/$Repository/archive/refs/tags/$Tag.zip"
    Write-Host "[download] $Name $Tag"
    Invoke-WebRequest -Uri $Url -OutFile $Zip
    Expand-Archive -Path $Zip -DestinationPath $Expanded -Force

    $RepoRoot = Get-ChildItem -Path $Expanded -Directory | Select-Object -First 1
    if ($null -eq $RepoRoot) { throw "Could not find extracted root for $Name" }

    $Source = Join-Path $RepoRoot.FullName $AddonPath
    if (-not (Test-Path $Source)) { throw "Missing addon path '$AddonPath' for $Name" }

    if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
    New-Item -ItemType Directory -Path $Addons -Force | Out-Null
    Copy-Item -Path $Source -Destination $Destination -Recurse -Force
    Write-Host "[ok] $Name -> addons/$DestinationName"
}

New-Item -ItemType Directory -Path $Temp -Force | Out-Null

Install-GitHubAddon -Name "GdUnit4" -Repository "godot-gdunit-labs/gdUnit4" -Tag $GdUnitVersion -AddonPath "addons/gdUnit4" -DestinationName "gdUnit4"
Install-GitHubAddon -Name "Godot State Charts" -Repository "derkork/godot-statecharts" -Tag $StateChartsVersion -AddonPath "addons/godot_state_charts" -DestinationName "godot_state_charts"

Write-Host ""
Write-Host "Gods & Liars dev addons ready."
Write-Host "GdUnit4: $GdUnitVersion"
Write-Host "State Charts: $StateChartsVersion"
Write-Host "Open the project in Godot 4.7 and enable editor plugins if Godot asks."
