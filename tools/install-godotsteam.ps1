param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Zip = (Resolve-Path $ZipPath).Path
$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("godotsteam-" + [guid]::NewGuid().ToString("N"))
$Target = Join-Path $Root "addons/godotsteam"

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

    Write-Host "GREEN: GodotSteam installed at addons/godotsteam"
}
finally {
    if (Test-Path $Temp) {
        Remove-Item -Path $Temp -Recurse -Force
    }
}
