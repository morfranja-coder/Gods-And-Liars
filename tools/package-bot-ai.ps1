param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$destination = [System.IO.Path]::GetFullPath($OutputDirectory)
$models = Join-Path $projectRoot ".tools/bot-models"
New-Item -ItemType Directory -Force (Join-Path $destination "ai_models") | Out-Null
$qwen = Join-Path $models "qwen-debate.gguf"
if (-not (Test-Path $qwen)) { throw "Falta el modelo de conversación ya existente." }
if ((Get-FileHash -LiteralPath $qwen -Algorithm SHA256).Hash.ToLower() -ne "3ebcddd7418577d7c6e64d35aece35fd4a7b7ac16aa75b84aa4179f257e656f0") { throw "Modelo Qwen inválido." }
Copy-Item -LiteralPath $qwen -Destination (Join-Path $destination "ai_models/qwen-debate.gguf") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "licenses/ai") -Destination $destination -Recurse -Force
$sourceDirectory = Join-Path $destination "ai/source"
New-Item -ItemType Directory -Force $sourceDirectory | Out-Null
foreach ($source in @(
    @{Name="nobodywho-12.0.0.zip"; Url="https://github.com/nobodywho-ooo/nobodywho/archive/refs/tags/nobodywho-godot-v12.0.0.zip"}
)) {
    $cache = Join-Path $projectRoot (".tools/" + $source.Name)
    if (-not (Test-Path $cache)) { Invoke-WebRequest $source.Url -OutFile $cache }
    Copy-Item -LiteralPath $cache -Destination (Join-Path $sourceDirectory $source.Name) -Force
}

$phonemizer = Get-Content (Join-Path $projectRoot "assets/ai/phonemizer_manifest.json") -Raw | ConvertFrom-Json
foreach ($crate in $phonemizer) {
    $name = "$($crate.name)-$($crate.version).crate"
    $cachedSource = Join-Path $projectRoot (".tools/" + $name)
    if (-not (Test-Path $cachedSource)) {
        Invoke-WebRequest "https://static.crates.io/crates/$($crate.name)/$name" -OutFile $cachedSource
    }
    if ((Get-FileHash -LiteralPath $cachedSource -Algorithm SHA256).Hash.ToLower() -ne $crate.sha256) { throw "Fuente del fonemizador inválida: $name" }
    Copy-Item -LiteralPath $cachedSource -Destination (Join-Path $sourceDirectory $name) -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot "assets/ai/phonemizer_manifest.json") -Destination (Join-Path $destination "ai/phonemizer_manifest.json") -Force

Write-Host "Modelo de conversación offline y licencias incluidos junto al ejecutable."
