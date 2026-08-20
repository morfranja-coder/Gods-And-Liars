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
        Write-Warning "Godot returned exit code $exportExitCode after producing a valid Windows executable; accepting artifact after validation."
    }

    Write-Host "GREEN: Windows build created at $Output ($($exe.Length) bytes)"
}
finally {
    Pop-Location
}
