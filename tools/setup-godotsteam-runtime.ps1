param(
    [string]$InstallRoot = ".tools/godotsteam",
    [string]$GodotSteamVersion = "4.20"
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $Root

try {
    if ($GodotSteamVersion -ne "4.20") {
        throw "This project currently pins GodotSteam 4.20 for Godot 4.7 / Steamworks 1.64"
    }

    $installPath = Join-Path $Root $InstallRoot
    $downloads = Join-Path $installPath "downloads"
    $editorArchive = Join-Path $downloads "linux64-g47-s164-gs420-editor.tar.xz"
    $templatesArchive = Join-Path $downloads "godotsteam-g47-s164-gs420-templates.tar.xz"
    $releaseBase = "https://codeberg.org/godotsteam/godotsteam/releases/download/v4.20"

    New-Item -ItemType Directory -Path $downloads -Force | Out-Null

    Write-Host "[1/4] Downloading pinned GodotSteam editor"
    Invoke-WebRequest -Uri "$releaseBase/linux64-g47-s164-gs420-editor.tar.xz" -OutFile $editorArchive

    Write-Host "[2/4] Downloading pinned GodotSteam export templates"
    Invoke-WebRequest -Uri "$releaseBase/godotsteam-g47-s164-gs420-templates.tar.xz" -OutFile $templatesArchive

    Write-Host "[3/4] Extracting editor"
    $editorDir = Join-Path $installPath "editor"
    if (Test-Path $editorDir) { Remove-Item $editorDir -Recurse -Force }
    New-Item -ItemType Directory -Path $editorDir -Force | Out-Null
    & tar -xJf $editorArchive -C $editorDir
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract GodotSteam editor archive" }

    $editor = Get-ChildItem -Path $editorDir -Recurse -File |
        Where-Object {
            $_.Name -match "godotsteam" -and
            $_.Name -match "editor" -and
            $_.Name -notmatch "\.so$" -and
            $_.Name -notmatch "\.txt$"
        } |
        Select-Object -First 1
    if ($null -eq $editor) {
        throw "Could not locate extracted GodotSteam editor binary"
    }
    if (-not $IsWindows) {
        & chmod +x $editor.FullName
        if ($LASTEXITCODE -ne 0) { throw "Failed to mark GodotSteam editor executable" }
    }

    Write-Host "[4/4] Installing matching export templates"
    $templateTemp = Join-Path $installPath "templates-expanded"
    if (Test-Path $templateTemp) { Remove-Item $templateTemp -Recurse -Force }
    New-Item -ItemType Directory -Path $templateTemp -Force | Out-Null
    & tar -xJf $templatesArchive -C $templateTemp
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract GodotSteam templates archive" }

    $templateRoot = Get-ChildItem -Path $templateTemp -Recurse -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName "windows_release_x86_64.exe") } |
        Select-Object -First 1
    if ($null -eq $templateRoot) {
        throw "Could not locate GodotSteam Windows export template"
    }

    $godotData = if ($IsWindows) {
        Join-Path $env:APPDATA "Godot/export_templates/4.7.stable"
    }
    else {
        Join-Path $HOME ".local/share/godot/export_templates/4.7.stable"
    }
    New-Item -ItemType Directory -Path $godotData -Force | Out-Null
    Copy-Item -Path (Join-Path $templateRoot.FullName "*") -Destination $godotData -Recurse -Force

    $resolvedEditor = $editor.FullName
    Set-Content -Path (Join-Path $installPath "editor-path.txt") -Value $resolvedEditor -NoNewline
    Write-Host "GREEN: GodotSteam runtime ready: $resolvedEditor"
}
finally {
    Pop-Location
}
