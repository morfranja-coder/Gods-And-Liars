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

    $win64Dir = Get-ChildItem -Path $templateTemp -Recurse -Directory |
        Where-Object { $_.Name -eq "win64" } |
        Select-Object -First 1
    if ($null -eq $win64Dir) {
        throw "Could not locate win64 directory in GodotSteam template archive"
    }

    $windowsRelease = Get-ChildItem -Path $win64Dir.FullName -File |
        Where-Object {
            $_.Name -match "\.template\.win64\.exe$" -and
            $_.Name -notmatch "\.debug\."
        } |
        Select-Object -First 1
    $windowsDebug = Get-ChildItem -Path $win64Dir.FullName -File |
        Where-Object { $_.Name -match "\.debug\.template\.win64\.exe$" } |
        Select-Object -First 1
    $steamApi = Get-ChildItem -Path $win64Dir.FullName -File -Filter "steam_api64.dll" |
        Select-Object -First 1

    if ($null -eq $windowsRelease -or $null -eq $windowsDebug -or $null -eq $steamApi) {
        Write-Host "win64 archive contents:" -ForegroundColor Yellow
        Get-ChildItem -Path $win64Dir.FullName -File |
            ForEach-Object { Write-Host "  $($_.FullName)" }
        throw "GodotSteam win64 package is missing release, debug, or steam_api64.dll"
    }

    Write-Host "Detected release template: $($windowsRelease.Name)"
    Write-Host "Detected debug template: $($windowsDebug.Name)"
    Write-Host "Detected Steam runtime DLL: $($steamApi.Name)"

    $godotData = if ($IsWindows) {
        Join-Path $env:APPDATA "Godot/export_templates/4.7.stable"
    }
    else {
        Join-Path $HOME ".local/share/godot/export_templates/4.7.stable"
    }
    New-Item -ItemType Directory -Path $godotData -Force | Out-Null

    Copy-Item -Path $windowsRelease.FullName -Destination (Join-Path $godotData "windows_release_x86_64.exe") -Force
    Copy-Item -Path $windowsDebug.FullName -Destination (Join-Path $godotData "windows_debug_x86_64.exe") -Force
    Copy-Item -Path $steamApi.FullName -Destination (Join-Path $godotData "steam_api64.dll") -Force

    $resolvedEditor = $editor.FullName
    Set-Content -Path (Join-Path $installPath "editor-path.txt") -Value $resolvedEditor -NoNewline
    Write-Host "GREEN: GodotSteam runtime ready: $resolvedEditor"
}
finally {
    Pop-Location
}
