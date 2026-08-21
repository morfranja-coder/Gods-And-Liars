param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "GodsAndLiars/Godot46"),
    [string]$McpName = "godot46-visual",
    [string]$McpVersion = "0.26.0",
    [switch]$SkipMcpRegistration
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not $IsWindows) {
    throw "This helper is intended for the local Windows workstation."
}

$downloadUrl = "https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.6"
$downloads = Join-Path $InstallRoot "downloads"
$archive = Join-Path $downloads "Godot_v4.6-stable_win64.exe.zip"
$editorDir = Join-Path $InstallRoot "editor"

New-Item -ItemType Directory -Path $downloads -Force | Out-Null

Write-Host "== Gods & Liars local Godot 4.6 + MCP setup =="
Write-Host "[1/4] Downloading official Godot 4.6 stable (Windows x86_64)"
if (-not (Test-Path $archive)) {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archive
}
else {
    Write-Host "[cached] $archive"
}

Write-Host "[2/4] Extracting Godot 4.6"
if (Test-Path $editorDir) {
    Remove-Item -Path $editorDir -Recurse -Force
}
New-Item -ItemType Directory -Path $editorDir -Force | Out-Null
Expand-Archive -Path $archive -DestinationPath $editorDir -Force

$godot = Get-ChildItem -Path $editorDir -Recurse -File -Filter "Godot_v4.6-stable_win64.exe" |
    Select-Object -First 1
if ($null -eq $godot) {
    throw "Could not locate Godot_v4.6-stable_win64.exe after extraction."
}

$versionOutput = (& $godot.FullName --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "^4\.6") {
    throw "Godot 4.6 validation failed. Reported version: '$versionOutput'"
}
Write-Host "[ok] Godot: $versionOutput"
Write-Host "[ok] Path: $($godot.FullName)"

Write-Host "[3/4] Checking Node.js / npx for Godot MCP Enhanced"
$node = Get-Command node.exe -ErrorAction SilentlyContinue
$npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
if ($null -eq $node -or $null -eq $npx) {
    throw "Node.js 18+ with npx is required for Godot MCP Enhanced. Install Node.js and rerun this script."
}

$nodeVersion = (& $node.Source --version | Out-String).Trim()
if ($nodeVersion -notmatch "^v(?<major>\d+)") {
    throw "Could not parse Node.js version: '$nodeVersion'"
}
if ([int]$Matches.major -lt 18) {
    throw "Godot MCP Enhanced requires Node.js 18+. Found $nodeVersion"
}
Write-Host "[ok] Node.js: $nodeVersion"

Write-Host "[4/4] Registering Codex MCP '$McpName'"
if ($SkipMcpRegistration) {
    Write-Host "[skip] MCP registration skipped by request."
}
else {
    $codex = Get-Command codex -ErrorAction SilentlyContinue
    if ($null -eq $codex) {
        throw "Codex CLI was not found in PATH. Install/open Codex CLI and rerun, or use -SkipMcpRegistration."
    }

    & $codex.Source mcp get $McpName --json *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[replace] Removing existing MCP '$McpName'"
        & $codex.Source mcp remove $McpName
        if ($LASTEXITCODE -ne 0) {
            throw "Could not remove existing MCP '$McpName'."
        }
    }

    & $codex.Source mcp add $McpName `
        --env "GODOT_PATH=$($godot.FullName)" `
        --env "GODOT_MCP_ALLOWED_GODOT_PATHS=$($godot.FullName)" `
        --env "ALLOWED_PROJECT_PATHS=$Root" `
        --env "GODOT_MCP_UPDATE_CHECK=false" `
        --env "GODOT_MCP_PROFILE=basic" `
        -- $npx.Source -y "godot-mcp-enhanced@$McpVersion"
    if ($LASTEXITCODE -ne 0) {
        throw "Codex failed to register MCP '$McpName'."
    }

    & $codex.Source mcp get $McpName --json
    if ($LASTEXITCODE -ne 0) {
        throw "MCP '$McpName' was added but could not be read back from Codex configuration."
    }
}

Write-Host ""
Write-Host "GREEN: Godot 4.6 local setup is ready."
Write-Host "IMPORTANT: Gods & Liars remains a Godot 4.7 project."
Write-Host "Do not resave project.godot or game scenes with Godot 4.6."
Write-Host "The '$McpName' server is a separate QA MCP bound specifically to Godot 4.6."
