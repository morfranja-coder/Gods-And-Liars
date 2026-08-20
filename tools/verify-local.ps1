param(
    [string]$GodotBinary = "godot"
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $Root

try {
    Write-Host "== Gods & Liars local quality gate =="

    Write-Host "[1/6] Installing pinned addons"
    & "$PSScriptRoot/setup-dev-tools.ps1" -Force

    Write-Host "[2/6] Checking gdtoolkit"
    $gdlint = Get-Command gdlint -ErrorAction SilentlyContinue
    if ($null -eq $gdlint) {
        throw "gdlint is missing. Install it with: pip install gdtoolkit==4.5.0"
    }
    & gdlint --version

    Write-Host "[3/6] Linting GDScript"
    & gdlint autoload scenes scripts tests
    if ($LASTEXITCODE -ne 0) { throw "gdlint failed" }

    Write-Host "[4/6] Parsing project in Godot headless"
    & $GodotBinary --headless --path . --editor --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot import/parse failed" }

    Write-Host "[5/6] Running smoke tests"
    & $GodotBinary --headless --path . --script tests/smoke_match_rules.gd
    if ($LASTEXITCODE -ne 0) { throw "Smoke tests failed" }

    Write-Host "[6/6] Running GdUnit4"
    $runner = Join-Path $Root "addons/gdUnit4/runtest.cmd"
    if (-not (Test-Path $runner)) { throw "GdUnit4 runner not found" }
    & $runner --godot_binary $GodotBinary --headless --continue --add tests/unit
    if ($LASTEXITCODE -ne 0) { throw "GdUnit4 failed" }

    Write-Host ""
    Write-Host "GREEN: local quality gate passed."
}
finally {
    Pop-Location
}
