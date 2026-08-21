param(
    [Parameter(Mandatory = $true)]
    [string]$BuildDir,
    [string]$ClientLabel = "client"
)

$ErrorActionPreference = "Stop"
$resolvedBuildDir = (Resolve-Path $BuildDir).Path
$exe = Join-Path $resolvedBuildDir "GodsAndLiars.exe"
$steamApi = Join-Path $resolvedBuildDir "steam_api64.dll"
$appIdFile = Join-Path $resolvedBuildDir "steam_appid.txt"

Write-Host "== Gods & Liars Steam QA client =="

foreach ($required in @($exe, $steamApi, $appIdFile)) {
    if (-not (Test-Path $required)) {
        throw "Missing required Steam QA artifact file: $required"
    }
}

$appId = (Get-Content $appIdFile -Raw).Trim()
if ($appId -ne "480") {
    throw "Expected development Steam App ID 480, found '$appId'."
}

$steam = Get-Process steam -ErrorAction SilentlyContinue
if ($null -eq $steam) {
    throw "Steam is not running. Start Steam, sign in, then rerun this command."
}

$env:GODS_LIARS_QA_LOG = "1"
$env:GODS_LIARS_QA_CLIENT = $ClientLabel

Write-Host "Client label: $ClientLabel"
Write-Host "Build: $resolvedBuildDir"
Write-Host "Steam App ID: $appId"
Write-Host "QA logging: enabled"
Write-Host "Launching GodsAndLiars.exe..."

$process = Start-Process -FilePath $exe -WorkingDirectory $resolvedBuildDir -PassThru
Write-Host "GREEN: client launched (PID $($process.Id))."
Write-Host "Expected log name: qa-session-$($ClientLabel.ToLower()).log"
Write-Host "Godot user data is normally under:"
Write-Host "  $env:APPDATA\Godot\app_userdata\Gods & Liars\"
