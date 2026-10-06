param([switch]$SkipModels)
$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$cache = Join-Path $projectRoot ".tools/bot-ai-downloads"
New-Item -ItemType Directory -Force $cache | Out-Null
$tag = "nobodywho-godot-v12.0.0"
$archive = Join-Path $cache "nobodywho.zip"
if (-not (Test-Path $archive) -and (Test-Path (Join-Path $projectRoot ".tools/nobodywho/addon.zip"))) {
    Copy-Item (Join-Path $projectRoot ".tools/nobodywho/addon.zip") $archive
}
if (-not (Test-Path $archive)) {
    Invoke-WebRequest "https://github.com/nobodywho-ooo/nobodywho/releases/download/$tag/nobodywho-godot-$tag.zip" -OutFile $archive
}
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $cache "unpacked") -Force
Copy-Item -LiteralPath (Join-Path $cache "unpacked/bin/addons/nobodywho") -Destination (Join-Path $projectRoot "addons") -Recurse -Force
if ($SkipModels) { return }
$models = Join-Path $projectRoot ".tools/bot-models"
New-Item -ItemType Directory -Force $models | Out-Null
function Get-ModelFile($repository, $revision, $file, $destination) {
    if (-not (Test-Path $destination)) {
        $temporary = $destination + ".download"
        Invoke-WebRequest "https://huggingface.co/$repository/resolve/$revision/$file" -OutFile $temporary
        Move-Item -LiteralPath $temporary -Destination $destination -Force
    }
}
Get-ModelFile "NobodyWho/Qwen_Qwen3-1.7B-GGUF" "d7b9d0be1d21f893a1788735530329ae2416b61b" "Qwen_Qwen3-1.7B-Q4_K_M.gguf" (Join-Path $models "qwen-debate.gguf")
Write-Host "NobodyWho 12 y modelo de conversación local instalados. Reinicie Godot."

$expected = "3ebcddd7418577d7c6e64d35aece35fd4a7b7ac16aa75b84aa4179f257e656f0"
if ((Get-FileHash -LiteralPath (Join-Path $models "qwen-debate.gguf") -Algorithm SHA256).Hash.ToLower() -ne $expected) {
    throw "El modelo de conversación no coincide con la descarga oficial."
}
