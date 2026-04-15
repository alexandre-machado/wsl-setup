$ErrorActionPreference = "Stop"

$targetDistro = "Ubuntu-24.04"
$targetDistroLabel = "Ubuntu 24.04 LTS"

function Get-WslPackageInstalled {
    $wslList = winget list --id Microsoft.WSL 2>&1 | Out-String
    return -not ($wslList -match 'No installed package found matching input criteria' -or $wslList -notmatch 'Microsoft\.WSL')
}

function Get-WslDistroNames {
    try {
        return @(wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    } catch {
        return @()
    }
}

function Write-PreflightSummary {
    param(
        [bool]$WslInstalled,
        [string[]]$DistroNames
    )

    $targetExists = $DistroNames -contains $targetDistro
    $hasAnyDistro = $DistroNames.Count -gt 0

    Write-Host ""
    Write-Host "=== WSL bootstrap preflight summary ===" -ForegroundColor Cyan
    Write-Host ("WSL package installed: {0}" -f ($(if ($WslInstalled) { "Yes" } else { "No" })))
    Write-Host ("Existing WSL distros: {0}" -f ($(if ($hasAnyDistro) { $DistroNames -join ", " } else { "None detected" })))
    Write-Host ("Target distro ({0}) exists: {1}" -f $targetDistroLabel, ($(if ($targetExists) { "Yes" } else { "No" })))
    Write-Host "Available paths:"
    Write-Host "- create-new (default): Yes"
    Write-Host ("- use-existing: {0}" -f ($(if ($hasAnyDistro) { "Yes" } else { "No" })))
    Write-Host ("- replace-existing: {0}" -f ($(if ($targetExists) { "Yes" } else { "No" })))
    Write-Host ""
}

function Ensure-WslPackageInstalled {
    param([bool]$WslInstalled)

    if ($WslInstalled) {
        return
    }

    Write-Host "WSL (Microsoft.WSL) não encontrado. Instalando via winget..." -ForegroundColor Yellow
    winget install --id Microsoft.WSL --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao instalar WSL via winget. Tente manualmente: winget install --id Microsoft.WSL --exact" -ForegroundColor Red
        exit 1
    }

    Write-Host "WSL instalado via winget." -ForegroundColor Green
}

function Ensure-CreateNewPath {
    param([bool]$WslInstalled)

    Ensure-WslPackageInstalled -WslInstalled $WslInstalled

    wsl --update
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao atualizar WSL." -ForegroundColor Red
        exit 1
    }

    $existingDistros = Get-WslDistroNames
    if (-not ($existingDistros -contains $targetDistro)) {
        wsl --install -d $targetDistro
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Falha ao instalar $targetDistro." -ForegroundColor Red
            exit 1
        }
    }

    wsl --set-default $targetDistro
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao definir $targetDistro como padrão." -ForegroundColor Red
        exit 1
    }
}

function Invoke-BashHandoff {
    param(
        [string]$GitName,
        [string]$GitEmail
    )

    wsl ~ -e bash -lc "echo 'Starting WSL setup...' && export GIT_NAME='$GitName' && export GIT_EMAIL='$GitEmail' && git clone https://github.com/alexandre-machado/wsl-setup.git && chmod 700 wsl-setup/ -R && cd wsl-setup && ./setup.sh"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha na transferência para o setup Bash." -ForegroundColor Red
        exit 1
    }
}

wsl --help > $null 2>&1

$wslPackageInstalled = Get-WslPackageInstalled
$existingDistros = Get-WslDistroNames
Write-PreflightSummary -WslInstalled $wslPackageInstalled -DistroNames $existingDistros

$modeChoice = Read-Host "Select bootstrap mode [create-new/use-existing/replace-existing] (default: create-new)"
if ([string]::IsNullOrWhiteSpace($modeChoice)) {
    $modeChoice = "create-new"
}

$normalizedModeChoice = $modeChoice.Trim().ToLowerInvariant()
$bootstrapMode = $null
if ($normalizedModeChoice -in @("create-new", "create", "new")) {
    $bootstrapMode = "create-new"
} elseif ($normalizedModeChoice -in @("use-existing", "existing", "keep")) {
    $bootstrapMode = "use-existing"
} elseif ($normalizedModeChoice -in @("replace-existing", "replace", "reset")) {
    $bootstrapMode = "replace-existing"
}

if (-not $bootstrapMode) {
    Write-Host "Modo inválido. Use create-new, use-existing, ou replace-existing." -ForegroundColor Red
    exit 1
}

switch ($bootstrapMode) {
    "create-new" {
        Ensure-CreateNewPath -WslInstalled $wslPackageInstalled
    }
    "use-existing" {
        if (-not $existingDistros -or $existingDistros.Count -eq 0) {
            Write-Host "Nenhuma distro WSL existente foi detectada para o caminho use-existing." -ForegroundColor Red
            exit 1
        }

        Write-Host "Using existing WSL distro(s) without destructive changes." -ForegroundColor Green
    }
    "replace-existing" {
        $confirmation = Read-Host "Confirm replace of the existing Ubuntu distro with $targetDistro? [Y/N]"
        if ($confirmation.Trim().ToUpperInvariant() -ne "Y") {
            Write-Host "No destructive fallback: continuing with the non-destructive create-new path." -ForegroundColor Yellow
            Ensure-CreateNewPath -WslInstalled $wslPackageInstalled
            break
        }

        Ensure-WslPackageInstalled -WslInstalled $wslPackageInstalled

        wsl --update
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Falha ao atualizar WSL." -ForegroundColor Red
            exit 1
        }

        $existingDistros = Get-WslDistroNames
        if ($existingDistros -contains $targetDistro) {
            wsl --unregister $targetDistro
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Falha ao remover $targetDistro durante replace-existing." -ForegroundColor Red
                exit 1
            }
        }

        wsl --install -d $targetDistro
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Falha ao reinstalar $targetDistro." -ForegroundColor Red
            exit 1
        }

        wsl --set-default $targetDistro
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Falha ao definir $targetDistro como padrão." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "1/2 WSL on Windows is installed." -ForegroundColor Green

# Prompt for Git variables
$defaultGitName = "Alexandre Machado"
$defaultGitEmail = "alexandre@machado.cc"

$GIT_NAME = Read-Host "Enter your name for Git [$defaultGitName]"
if ([string]::IsNullOrWhiteSpace($GIT_NAME)) { $GIT_NAME = $defaultGitName }

$GIT_EMAIL = Read-Host "Enter your email for Git [$defaultGitEmail]"
if ([string]::IsNullOrWhiteSpace($GIT_EMAIL)) { $GIT_EMAIL = $defaultGitEmail }

Invoke-BashHandoff -GitName $GIT_NAME -GitEmail $GIT_EMAIL

Write-Host "2/2 WSL on Windows is set up" -ForegroundColor Green
