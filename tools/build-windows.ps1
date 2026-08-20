param(
    [string]$GodotBinary = "godot",
    [string]$Preset = "Windows Desktop",
    [string]$Output = "build/windows/GodsAndLiars.exe"
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $Root

try {
    Write-Host "== Gods & Liars Windows build =="

    if (-not (Test-Path "export_presets.cfg")) {
        throw "export_presets.cfg is missing"
    }

    $outputDir = Split-Path $Output -Parent
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    Write-Host "[1/3] Installing pinned development addons"
    & "$PSScriptRoot/setup-dev-tools.ps1" -Force

    Write-Host "[2/3] Importing project"
    & $GodotBinary --headless --path . --editor --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

    Write-Host "[3/3] Exporting Windows release"
    & $GodotBinary --headless --path . --export-release $Preset $Output
    if ($LASTEXITCODE -ne 0) { throw "Windows export failed" }

    if (-not (Test-Path $Output)) {
        throw "Expected executable was not produced: $Output"
    }

    Write-Host "GREEN: Windows build created at $Output"
}
finally {
    Pop-Location
}
