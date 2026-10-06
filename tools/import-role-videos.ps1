param(
    [Parameter(Mandatory=$true)][string]$SourceDirectory,
    [string]$FfmpegBinary = "ffmpeg"
)
$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputDirectory = Join-Path $projectRoot "assets/videos/roles"
New-Item -ItemType Directory -Force $outputDirectory | Out-Null
$clips = @{
    faithful = "Selección Fiel.mp4"
    heretic = "Selección Hereje.mp4"
    priest = "Selección Sacerdote.mp4"
    inquisitor = "Selección Inquisidor.mp4"
}
foreach ($role in $clips.Keys) {
    $source = Join-Path $SourceDirectory $clips[$role]
    $quality = 8
    if ($role -eq "heretic") {
        $hdSource = Join-Path $SourceDirectory "Selección Hereje HD.mp4"
        if (Test-Path -LiteralPath $hdSource) { $source = $hdSource; $quality = 10 }
    }
    if (-not (Test-Path -LiteralPath $source)) { throw "Falta el video $source" }
    $temporary = Join-Path $outputDirectory "$role.pending.ogv"
    & $FfmpegBinary -hide_banner -loglevel error -i $source -t 10 -map 0:v:0 -map 0:a:0 -c:v libtheora -q:v $quality -pix_fmt yuv420p -c:a libvorbis -q:a 5 -y $temporary
    if ($LASTEXITCODE -ne 0) { throw "Falló la conversión de $role" }
    Move-Item -LiteralPath $temporary -Destination (Join-Path $outputDirectory "$role.ogv") -Force
    Write-Host "Video de $role importado con sonido."
}
