param(
    [string]$GodotBinary = "godot"
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $Root

try {
    Write-Host "== Gods & Liars release readiness gate =="

    Write-Host "[1/5] Running local quality gate"
    & "$PSScriptRoot/verify-local.ps1" -GodotBinary $GodotBinary
    if ($LASTEXITCODE -ne 0) { throw "Local quality gate failed" }

    Write-Host "[2/5] Checking Windows export preset"
    if (-not (Test-Path "export_presets.cfg")) {
        throw "export_presets.cfg is missing"
    }

    Write-Host "[3/5] Checking Steam development App ID"
    if (-not (Test-Path "steam_appid.txt")) {
        throw "steam_appid.txt is missing"
    }
    $appId = (Get-Content "steam_appid.txt" -Raw).Trim()
    if ($appId -ne "480") {
        throw "Expected development Steam App ID 480, found '$appId'"
    }

    Write-Host "[4/5] Checking GodotSteam GDExtension"
    $extension = "addons/godotsteam/godotsteam.gdextension"
    if (-not (Test-Path $extension)) {
        throw "GodotSteam is missing. Install the pinned official GDExtension before release validation."
    }

    Write-Host "[5/5] Building Windows release"
    & "$PSScriptRoot/build-windows.ps1" -GodotBinary $GodotBinary
    if ($LASTEXITCODE -ne 0) { throw "Windows release build failed" }

    Write-Host ""
    Write-Host "GREEN: release readiness gate passed."
}
finally {
    Pop-Location
}
