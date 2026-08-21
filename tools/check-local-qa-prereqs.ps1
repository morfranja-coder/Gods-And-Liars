param(
    [string]$Godot47InstallRoot = (Join-Path $env:LOCALAPPDATA "GodsAndLiars/Godot47"),
    [string]$McpName = "godot47-visual"
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()
$runningOnWindows = $env:OS -eq "Windows_NT"

function Report-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    if ($Passed) {
        Write-Host "[GREEN] $Name - $Detail"
    }
    else {
        Write-Host "[RED]   $Name - $Detail" -ForegroundColor Red
        $failures.Add("${Name}: $Detail")
    }
}

Write-Host "== Gods & Liars local QA preflight =="

Report-Check "Windows" $runningOnWindows "local QA scripts target Windows"

$git = Get-Command git.exe -ErrorAction SilentlyContinue
$gitDetail = if ($git) { (& $git.Source --version | Out-String).Trim() } else { "git.exe not found" }
Report-Check "Git" ($null -ne $git) $gitDetail

$steam = Get-Process steam -ErrorAction SilentlyContinue
Report-Check "Steam" ($null -ne $steam) $(if ($steam) { "running" } else { "not running" })

$node = Get-Command node.exe -ErrorAction SilentlyContinue
$nodeOk = $false
$nodeDetail = "node.exe not found"
if ($node) {
    $nodeDetail = (& $node.Source --version | Out-String).Trim()
    if ($nodeDetail -match "^v(?<major>\d+)") {
        $nodeOk = [int]$Matches.major -ge 18
    }
}
Report-Check "Node.js 18+" $nodeOk $nodeDetail

$npx = Get-Command npx.cmd -ErrorAction SilentlyContinue
Report-Check "npx" ($null -ne $npx) $(if ($npx) { $npx.Source } else { "npx.cmd not found" })

$codex = Get-Command codex.cmd -ErrorAction SilentlyContinue
if ($null -eq $codex) {
    $codex = Get-Command codex.exe -ErrorAction SilentlyContinue
}
if ($null -eq $codex) {
    $codex = Get-Command codex -ErrorAction SilentlyContinue
}
Report-Check "Codex CLI" ($null -ne $codex) $(if ($codex) { $codex.Source } else { "codex not found in PATH" })

$godot47 = Get-ChildItem `
    -Path (Join-Path $Godot47InstallRoot "editor") `
    -Recurse `
    -File `
    -Filter "Godot_v4.7-stable_win64.exe" `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1
$godot47Ok = $false
$godot47Detail = "not installed"
if ($godot47) {
    $godot47Detail = (& $godot47.FullName --version | Out-String).Trim()
    $godot47Ok = $LASTEXITCODE -eq 0 -and $godot47Detail -match "^4\.7"
}
Report-Check "Godot 4.7" $godot47Ok $godot47Detail

$mcpOk = $false
$mcpDetail = "not configured"
if ($codex) {
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $mcpOutput = & $codex.Source mcp get $McpName --json 2>$null | Out-String
    $mcpExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    if ($mcpExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($mcpOutput)) {
        $mcpOk = $true
        $mcpDetail = "registered as '$McpName'"
    }
}
Report-Check "Godot 4.7 MCP" $mcpOk $mcpDetail

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "RED: local QA preflight has $($failures.Count) missing requirement(s)." -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure"
    }
    exit 1
}

Write-Host "GREEN: local QA workstation prerequisites are ready."
Write-Host "Gods & Liars development, QA and MCP are standardized on Godot 4.7."
exit 0
