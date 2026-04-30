$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$OutFile = if ($args.Count -gt 0) { $args[0] } else { Join-Path $RootDir "fishtools.sh" }

$Parts = @(
    "src/00_globals.sh",
    "src/core/10_package.sh",
    "src/core/20_cli.sh",
    "src/core/30_common.sh",
    "src/ui/10_draw.sh",
    "src/modules/10_status.sh",
    "src/modules/20_docker.sh",
    "src/modules/30_web_proxy.sh",
    "src/modules/40_install_tools.sh",
    "src/modules/50_tests_dd.sh",
    "src/modules/60_optimization.sh",
    "src/modules/70_deploy.sh",
    "src/modules/80_system_tools.sh",
    "src/modules/90_gost.sh",
    "src/modules/95_openclaw.sh",
    "src/modules/96_ai_agents.sh",
    "src/99_main.sh"
)

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$Chunks = New-Object System.Collections.Generic.List[string]

foreach ($Part in $Parts) {
    $Path = Join-Path $RootDir $Part
    if (-not (Test-Path $Path)) {
        throw "Missing source part: $Part"
    }
    $Chunks.Add(([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)).TrimEnd("`r", "`n"))
}

$Content = ($Chunks -join "`n`n") + "`n"
[System.IO.File]::WriteAllText($OutFile, $Content, $Utf8NoBom)

Write-Host "Built $OutFile"
