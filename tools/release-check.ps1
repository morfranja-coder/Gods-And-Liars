param(
    [string]$GodotBinary = "godot"
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $Root

try {
    Write-Host "== Gods & Liars release readiness gate =="

    Write-Host "[1/6] Running local quality gate"
    & "$PSScriptRoot/verify-local.ps1" -GodotBinary $GodotBinary
    if ($LASTEXITCODE -ne 0) { throw "Local quality gate failed" }

    Write-Host "[2/6] Checking Windows export preset"
    if (-not (Test-Path "export_presets.cfg")) {
        throw "export_presets.cfg is missing"
    }

    Write-Host "[3/6] Checking Steam development App ID"
    if (-not (Test-Path "steam_appid.txt")) {
        throw "steam_appid.txt is missing"
    }
    $appId = (Get-Content "steam_appid.txt" -Raw).Trim()
    if ($appId -ne "480") {
        throw "Expected development Steam App ID 480, found '$appId'"
    }

    Write-Host "[4/6] Verifying full Steam multiplayer runtime"
    & $GodotBinary --headless --path . --script res://tools/verify-steam-runtime.gd
    if ($LASTEXITCODE -ne 0) {
        throw "Steam runtime gate failed. Use a GodotSteam build that exposes both Steam and SteamMultiplayerPeer."
    }

    Write-Host "[5/6] Building Windows release"
    & "$PSScriptRoot/build-windows.ps1" -GodotBinary $GodotBinary
    if ($LASTEXITCODE -ne 0) { throw "Windows release build failed" }

    Write-Host "[6/6] Verifying Windows artifact"
    $output = "build/windows/GodsAndLiars.exe"
    if (-not (Test-Path $output)) {
        throw "Windows artifact is missing after build"
    }

    Write-Host ""
    Write-Host "GREEN: release readiness gate passed."
}
finally {
    Pop-Location
}
