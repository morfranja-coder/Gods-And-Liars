param(
    [string]$GodotBinary = "godot",
    [string]$Preset = "Windows Desktop",
    [string]$Output = "build/windows/GodsAndLiars.exe",
    [switch]$IncludeSteamAppIdFile,
    [int]$ExpectedSteamAppId = 480
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

    & "$PSScriptRoot/setup-bot-ai.ps1"

    Write-Host "[2/3] Importing project"
    & $GodotBinary --headless --path . --editor --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

    Write-Host "[3/3] Exporting Windows release"
    & $GodotBinary --headless --path . --export-release $Preset $Output
    $exportExitCode = $LASTEXITCODE

    if (-not (Test-Path $Output)) {
        throw "Expected executable was not produced: $Output (Godot exit code $exportExitCode)"
    }

    $exe = Get-Item $Output
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

    if ($exportExitCode -ne 0) {
        throw "Godot export failed with exit code $exportExitCode; a partial artifact is not a successful build."
    }

    # GodotSteam templates require their native dependency beside the executable.
    $steamCandidates = @(Join-Path $Root ".tools/godotsteam/templates-expanded/win64/steam_api64.dll")
    if ($env:APPDATA) { $steamCandidates += Join-Path $env:APPDATA "Godot/export_templates/4.7.stable/steam_api64.dll" }
    foreach ($candidate in $steamCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            Copy-Item -LiteralPath $candidate -Destination (Join-Path $outputDir "steam_api64.dll") -Force

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
            break
        }
    }

    & "$PSScriptRoot/package-bot-ai.ps1" -OutputDirectory ((Resolve-Path -LiteralPath $outputDir).Path)

    Write-Host "GREEN: Windows build created at $Output ($($exe.Length) bytes)"
}
finally {
    Pop-Location
}

# Reset the CI wrapper exit code only after every validation succeeds.
$global:LASTEXITCODE = 0
exit 0
