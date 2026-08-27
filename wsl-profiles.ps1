<#
.SYNOPSIS
    Backwards-compatible wrapper for wsl-setup.ps1.

.DESCRIPTION
    Forwards all parameters to wsl-setup.ps1.
#>

param(
    [Alias("ConfigFile")]
    [string]$ConfigPath = $null,
    [switch]$DryRun,
    [switch]$Force
)

$setupScript = Join-Path $PSScriptRoot "wsl-setup.ps1"
if (-not (Test-Path -LiteralPath $setupScript)) {
    $setupScript = ".\wsl-setup.ps1"
}

& $setupScript -ConfigFile $ConfigPath -DryRun:$DryRun -Force:$Force
