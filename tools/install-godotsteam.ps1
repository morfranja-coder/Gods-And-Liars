param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Zip = (Resolve-Path $ZipPath).Path
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("godotsteam-" + [guid]::NewGuid().ToString("N"))
$Target = Join-Path $Root "addons/godotsteam"

Write-Warning "This installs the GodotSteam API GDExtension only. It does NOT provide SteamMultiplayerPeer and is not sufficient for the Gods & Liars MVP networking stack."
Write-Warning "For release validation use a GodotSteam MultiplayerPeer/module build compatible with Godot 4.7 + Steamworks 1.64."

try {
    New-Item -ItemType Directory -Path $Temp -Force | Out-Null
    Expand-Archive -Path $Zip -DestinationPath $Temp -Force

    $extension = Get-ChildItem -Path $Temp -Recurse -Filter "godotsteam.gdextension" | Select-Object -First 1
    if ($null -eq $extension) {
        throw "The ZIP does not contain godotsteam.gdextension"
    }

    $source = Split-Path $extension.FullName -Parent
    if (Test-Path $Target) {
        Remove-Item -Path $Target -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    Copy-Item -Path (Join-Path $source "*") -Destination $Target -Recurse -Force

    $installedExtension = Join-Path $Target "godotsteam.gdextension"
    if (-not (Test-Path $installedExtension)) {
        throw "GodotSteam installation failed"
    }

    Write-Host "GREEN: GodotSteam API GDExtension installed at addons/godotsteam"
    Write-Host "NOTE: release-check.ps1 will still fail unless the selected Godot binary exposes SteamMultiplayerPeer."
}
finally {
    if (Test-Path $Temp) {
        Remove-Item -Path $Temp -Recurse -Force
    }
}
