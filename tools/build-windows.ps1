param(
    [string]$GodotBinary = "godot",
    [string]$Preset = "Windows Desktop",
    [string]$Output = "build/windows/GodsAndLiars.exe",
    [switch]$IncludeSteamAppIdFile,
    [int]$ExpectedSteamAppId = 480
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ($GodotBinary -eq "godot") {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT) -and (Test-Path -LiteralPath $env:GODOT)) {
        $GodotBinary = $env:GODOT
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:GODOT4) -and (Test-Path -LiteralPath $env:GODOT4)) {
        $GodotBinary = $env:GODOT4
    }
}

Write-Host "Using Godot binary: $GodotBinary"
& $GodotBinary --version
if ($LASTEXITCODE -ne 0) {
    throw "Godot binary failed version probe with exit code $LASTEXITCODE"
}

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
    & "$PSScriptRoot/setup-bot-ai.ps1"

    Write-Host "[2/3] Importing project from a clean Godot cache"
    $godotCache = Join-Path $Root ".godot"
    if (Test-Path -LiteralPath $godotCache) {
        Remove-Item -LiteralPath $godotCache -Recurse -Force
    }

    # A pristine checkout has no generated .godot import cache. The first pass
    # creates imported resources and class metadata; the second verifies the
    # freshly generated cache before packaging.
    & $GodotBinary --headless --verbose --path . --editor --quit
    $firstImportExit = $LASTEXITCODE
    if ($firstImportExit -ne 0) {
        Write-Host "Godot first import exit code: $firstImportExit" -ForegroundColor Red
        throw "Godot first import pass failed"
    }

    & $GodotBinary --headless --verbose --path . --editor --quit
    $secondImportExit = $LASTEXITCODE
    if ($secondImportExit -ne 0) {
        Write-Host "Godot verification import exit code: $secondImportExit" -ForegroundColor Red
        throw "Godot import verification pass failed"
    }

    Write-Host "[3/3] Packaging Windows release"

    # Godot 4.7 can abort with SIGABRT after savepack while assembling a Windows
    # executable on a Linux runner, even though the project pack is complete.
    # Because this preset intentionally uses an external PCK (embed_pck=false),
    # build the PCK explicitly and pair it with the matching release template.
    $pckOutput = [System.IO.Path]::ChangeExtension($Output, ".pck")
    & $GodotBinary --headless --path . --export-pack $Preset $pckOutput
    $packExitCode = $LASTEXITCODE
    if ($packExitCode -ne 0) {
        throw "Godot pack export failed with exit code $packExitCode"
    }
    if (-not (Test-Path -LiteralPath $pckOutput)) {
        throw "Expected PCK was not produced: $pckOutput"
    }
    $pck = Get-Item -LiteralPath $pckOutput
    if ($pck.Length -lt 1024) {
        throw "Exported PCK is unexpectedly small: $($pck.Length) bytes"
    }

    $templateCandidates = @()
    $godotSteamTemplateRoot = Join-Path $Root ".tools/godotsteam/templates-expanded/win64"
    if (Test-Path -LiteralPath $godotSteamTemplateRoot) {
        $templateCandidates += Get-ChildItem -LiteralPath $godotSteamTemplateRoot -File |
            Where-Object {
                $_.Name -match "\.template\.win64\.exe$" -and
                $_.Name -notmatch "\.debug\."
            } |
            Select-Object -ExpandProperty FullName
    }

    if ($IsWindows -and $env:APPDATA) {
        $templateCandidates += Join-Path $env:APPDATA "Godot/export_templates/4.7.stable/windows_release_x86_64.exe"
    }
    else {
        $templateCandidates += Join-Path $HOME ".local/share/godot/export_templates/4.7.stable/windows_release_x86_64.exe"
    }

    $releaseTemplate = $templateCandidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($releaseTemplate)) {
        throw "Could not locate a Windows 4.7 release export template"
    }

    Copy-Item -LiteralPath $releaseTemplate -Destination $Output -Force

    if (-not (Test-Path -LiteralPath $Output)) {
        throw "Expected executable was not produced: $Output"
    }

    $exe = Get-Item -LiteralPath $Output
    if ($exe.Length -lt 1024) {
        throw "Exported executable is unexpectedly small: $($exe.Length) bytes"
    }

    $stream = [System.IO.File]::OpenRead($exe.FullName)
    try {
        $first = $stream.ReadByte()
        $second = $stream.ReadByte()
    }
    finally {
        $stream.Dispose()
    }

    if ($first -ne 0x4D -or $second -ne 0x5A) {
        throw "Exported file is not a valid Windows PE executable (missing MZ header)"
    }

    # GodotSteam templates require their native dependency beside the executable.
    $steamCandidates = @(Join-Path $Root ".tools/godotsteam/templates-expanded/win64/steam_api64.dll")
    if ($env:APPDATA) {
        $steamCandidates += Join-Path $env:APPDATA "Godot/export_templates/4.7.stable/steam_api64.dll"
    }
    if (-not $IsWindows) {
        $steamCandidates += Join-Path $HOME ".local/share/godot/export_templates/4.7.stable/steam_api64.dll"
    }

    foreach ($candidate in $steamCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            Copy-Item -LiteralPath $candidate -Destination (Join-Path $outputDir "steam_api64.dll") -Force
            break
        }
    }

    $outputAppId = Join-Path $outputDir "steam_appid.txt"
    if ($IncludeSteamAppIdFile) {
        $sourceAppId = Join-Path $Root "steam_appid.txt"
        if (-not (Test-Path -LiteralPath $sourceAppId)) {
            throw "steam_appid.txt is required for a local Steam QA build"
        }
        $actualAppId = (Get-Content -LiteralPath $sourceAppId -Raw).Trim()
        if ($actualAppId -ne [string]$ExpectedSteamAppId) {
            throw "Expected Steam App ID $ExpectedSteamAppId, got '$actualAppId'"
        }
        Copy-Item -LiteralPath $sourceAppId -Destination $outputAppId -Force
    }
    elseif (Test-Path -LiteralPath $outputAppId) {
        Remove-Item -LiteralPath $outputAppId -Force
    }

    & "$PSScriptRoot/package-bot-ai.ps1" -OutputDirectory ((Resolve-Path -LiteralPath $outputDir).Path)

    Write-Host "GREEN: Windows build created at $Output ($($exe.Length) bytes)"
    Write-Host "GREEN: Project pack created at $pckOutput ($($pck.Length) bytes)"
}
finally {
    Pop-Location
}

$global:LASTEXITCODE = 0
exit 0
