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
    if ($targetExists) {
        Write-Host ("  (replace-existing offers a 'wsl --export' backup of {0} before any unregister)" -f $targetDistro) -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Get-DistroDiskSizeBytes {
    # Best-effort size of the distro's virtual disk (ext4.vhdx), used to
    # estimate how large a 'wsl --export' tar will be. Returns $null when
    # the size cannot be determined.
    param([string]$DistroName)

    try {
        $lxssKeys = Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction Stop
        foreach ($key in $lxssKeys) {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DistributionName -eq $DistroName -and $props.BasePath) {
                $basePath = $props.BasePath -replace '^\\\\\?\\', ''
                $vhdx = Join-Path $basePath "ext4.vhdx"
                if (Test-Path $vhdx) {
                    return (Get-Item $vhdx).Length
                }
            }
        }
    } catch {
        return $null
    }
    return $null
}

function Invoke-WslDistroBackup {
    # Offers a 'wsl --export' snapshot before the destructive replace path.
    # Returns $true if a backup was exported, $false if the user declined.
    # Fail-safe: an export failure aborts the whole destructive path (exit 1)
    # so 'wsl --unregister' is never reached without a good backup or an
    # explicit decline.
    param([string]$DistroName)

    $dateStamp = Get-Date -Format yyyyMMdd-HHmmss
    $defaultDir = Join-Path $env:USERPROFILE "wsl-backups"
    $defaultPath = Join-Path $defaultDir "$DistroName-$dateStamp.tar"

    Write-Host ""
    Write-Host "=== Backup before replace ===" -ForegroundColor Cyan
    Write-Host "replace-existing will unregister $DistroName, permanently deleting its filesystem."
    Write-Host "A 'wsl --export' snapshot lets you restore it later with 'wsl --import'."

    $diskSize = Get-DistroDiskSizeBytes -DistroName $DistroName
    if ($diskSize) {
        Write-Host ("Estimated backup size: up to ~{0:N1} GB (current virtual disk size)." -f ($diskSize / 1GB))
    } else {
        Write-Host "Estimated backup size: could not be determined; expect several GB (roughly the distro's disk usage)."
    }
    try {
        $driveName = (Split-Path -Qualifier $defaultPath).TrimEnd(':')
        $freeBytes = (Get-PSDrive -Name $driveName -ErrorAction Stop).Free
        Write-Host ("Free space on {0}: {1:N1} GB." -f (Split-Path -Qualifier $defaultPath), ($freeBytes / 1GB))
    } catch {
        Write-Host "Free space on the target drive could not be determined."
    }

    $answer = Read-Host "Export a backup of $DistroName before replacing it? [Y/N] (default: Y)"
    if (-not [string]::IsNullOrWhiteSpace($answer) -and $answer.Trim().ToUpperInvariant() -eq "N") {
        Write-Host "Skipping backup at your request. $DistroName will NOT be recoverable after unregister." -ForegroundColor Yellow
        return $false
    }

    $backupPath = Read-Host "Backup file path [default: $defaultPath]"
    if ([string]::IsNullOrWhiteSpace($backupPath)) {
        $backupPath = $defaultPath
    }

    # Normalize to an absolute path before handing it to wsl.exe (PowerShell
    # and wsl.exe do not share relative-path/wildcard semantics).
    if (-not [System.IO.Path]::IsPathRooted($backupPath)) {
        $backupPath = Join-Path (Get-Location).Path $backupPath
    }
    $backupPath = [System.IO.Path]::GetFullPath($backupPath)

    $backupDir = Split-Path -Parent $backupPath
    if ($backupDir -and -not (Test-Path -LiteralPath $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    # Never silently clobber a prior backup.
    if (Test-Path -LiteralPath $backupPath) {
        $overwrite = Read-Host "A file already exists at `"$backupPath`". Overwrite it? [Y/N] (default: N)"
        if ([string]::IsNullOrWhiteSpace($overwrite) -or $overwrite.Trim().ToUpperInvariant() -ne "Y") {
            $suffix = 1
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($backupPath)
            $extension = [System.IO.Path]::GetExtension($backupPath)
            do {
                $backupPath = Join-Path $backupDir ("{0}-{1}{2}" -f $baseName, $suffix, $extension)
                $suffix++
            } while (Test-Path -LiteralPath $backupPath)
            Write-Host ("Keeping the existing file; exporting to `"{0}`" instead." -f $backupPath) -ForegroundColor Yellow
        }
    }

    Write-Host "Running: wsl --export $DistroName `"$backupPath`" (this can take several minutes)..."
    wsl --export $DistroName $backupPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $backupPath)) {
        Write-Host "wsl --export failed (exit code $LASTEXITCODE). Aborting the destructive replace-existing path; nothing was unregistered." -ForegroundColor Red
        Write-Host "Free up disk space or export manually, then re-run the bootstrap." -ForegroundColor Red
        exit 1
    }

    Write-Host ("Backup complete: {0}" -f $backupPath) -ForegroundColor Green
    Write-Host "To restore this distro later, run:" -ForegroundColor Green
    Write-Host ("  wsl --import {0} <install-folder> `"{1}`"" -f $DistroName, $backupPath)
    Write-Host ("  e.g. wsl --import {0} `"{1}`" `"{2}`"" -f $DistroName, (Join-Path $env:LOCALAPPDATA "wsl\$DistroName"), $backupPath)
    return $true
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

function Install-CloudInitUserData {
    # Renders scripts/cloud-init.user-data.template into
    # %USERPROFILE%\.cloud-init\<distro>.user-data so a brand-new instance is
    # pre-provisioned (user, locale, base packages) on first boot.
    # Official mechanism: https://documentation.ubuntu.com/wsl/latest/howto/cloud-init/
    # Every host-side write is printed before it happens; the rendered file is
    # shown to the user and requires confirmation. Returns $true when the
    # user-data file is in place, $false when cloud-init should be skipped.
    param([string]$DistroName)

    if ($DistroName -notmatch '^Ubuntu') {
        Write-Host "cloud-init user-data is only honored by Ubuntu WSL images; skipping it for $DistroName. The instance will boot unprovisioned and rely on setup.sh alone." -ForegroundColor Yellow
        return $false
    }

    $cloudInitDir = Join-Path $env:USERPROFILE ".cloud-init"
    $target = Join-Path $cloudInitDir "$DistroName.user-data"
    $marker = "# managed-by: wsl-setup"
    $templateUrl = "https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/scripts/cloud-init.user-data.template"

    try {
        $template = Invoke-WebRequest -UseBasicParsing -Uri $templateUrl | Select-Object -ExpandProperty Content
    } catch {
        Write-Host ("Falha ao baixar cloud-init.user-data.template de {0}: {1}" -f $templateUrl, $_.Exception.Message) -ForegroundColor Yellow
        Write-Host "Continuing without cloud-init; the instance will be set up interactively as before." -ForegroundColor Yellow
        return $false
    }

    # Reserved names are rejected because this account becomes the default
    # login user with passwordless sudo; 32 chars is useradd's limit.
    $reservedUsers = @("root", "admin", "administrator", "daemon", "sudo", "nobody")

    $defaultUser = ($env:USERNAME -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($defaultUser) -or $defaultUser -notmatch '^[a-z_]' -or $defaultUser.Length -gt 32 -or $reservedUsers -contains $defaultUser) {
        $defaultUser = "ubuntu"
    }
    $wslUser = Read-Host "Linux username for the new $DistroName instance [default: $defaultUser]"
    if ([string]::IsNullOrWhiteSpace($wslUser)) {
        $wslUser = $defaultUser
    }
    $wslUser = $wslUser.Trim()
    if ($wslUser -notmatch '^[a-z_][a-z0-9_-]*$' -or $wslUser.Length -gt 32 -or $reservedUsers -contains $wslUser) {
        Write-Host ("'{0}' is not an acceptable Linux username (must match ^[a-z_][a-z0-9_-]*$, be at most 32 characters, and not be a reserved name such as root); using '{1}' instead." -f $wslUser, $defaultUser) -ForegroundColor Yellow
        $wslUser = $defaultUser
    }

    $content = $template -replace '__USERNAME__', $wslUser

    Write-Host ""
    Write-Host "=== cloud-init user-data (host-side write) ===" -ForegroundColor Cyan
    Write-Host ("The following file will be written to `"{0}`":" -f $target)
    Write-Host "----------------------------------------------" -ForegroundColor DarkGray
    Write-Host $content
    Write-Host "----------------------------------------------" -ForegroundColor DarkGray

    # Fail-safe confirm gate: only an explicit Y/YES (or Enter for the
    # default) writes the file; N/NO and any unrecognized answer decline.
    $answer = Read-Host "Write this user-data file? [Y/N] (default: Y)"
    $answer = if ($null -eq $answer) { "" } else { $answer.Trim().ToUpperInvariant() }
    if ($answer -notin @("", "Y", "YES")) {
        Write-Host "Skipping cloud-init (answer was not Y/YES); $DistroName will be set up interactively as before." -ForegroundColor Yellow
        return $false
    }

    if (-not (Test-Path -LiteralPath $cloudInitDir)) {
        Write-Host ("Creating directory {0}" -f $cloudInitDir)
        New-Item -ItemType Directory -Path $cloudInitDir -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $target) -and -not (Select-String -Path $target -Pattern $marker -Quiet)) {
        $backup = "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $target -Destination $backup
        Write-Host ("Backed up existing unmanaged user-data to {0}" -f $backup) -ForegroundColor DarkGray
    }

    Set-Content -Path $target -Value $content -Encoding ASCII
    Write-Host ("cloud-init user-data written to {0}" -f $target) -ForegroundColor Green
    return $true
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
        # cloud-init only provisions instances that have never been launched,
        # so the user-data file must exist before the first boot and the
        # install must use --no-launch.
        $cloudInitEnabled = Install-CloudInitUserData -DistroName $targetDistro

        if ($cloudInitEnabled) {
            wsl --install -d $targetDistro --no-launch
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Falha ao instalar $targetDistro." -ForegroundColor Red
                exit 1
            }

            Write-Host "First boot of $targetDistro — waiting for cloud-init to finish (this can take several minutes)..." -ForegroundColor Cyan
            wsl -d $targetDistro -u root -- cloud-init status --wait
            $cloudInitExit = $LASTEXITCODE
            if ($cloudInitExit -eq 0) {
                Write-Host "cloud-init reports: provisioning completed successfully." -ForegroundColor Green
            } elseif ($cloudInitExit -eq 2) {
                Write-Host "cloud-init reports: done, with recoverable errors. Inspect with: wsl -d $targetDistro -u root -- cloud-init status --long" -ForegroundColor Yellow
            } else {
                Write-Host "cloud-init status --wait exited with code $cloudInitExit. Provisioning may be incomplete; inspect with: wsl -d $targetDistro -u root -- cloud-init status --long" -ForegroundColor Yellow
                Write-Host "Continuing — setup.sh will still run, but the default user/locale/base packages may be missing." -ForegroundColor Yellow
            }

            # /etc/wsl.conf ([user] default=...) written by cloud-init only
            # takes effect after the distro is restarted.
            wsl --terminate $targetDistro
        } else {
            wsl --install -d $targetDistro
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Falha ao instalar $targetDistro." -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host "$targetDistro already exists; skipping install (cloud-init only provisions brand-new instances)." -ForegroundColor DarkGray
    }

    wsl --set-default $targetDistro
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Falha ao definir $targetDistro como padrão." -ForegroundColor Red
        exit 1
    }
}

function Install-WslConfig {
    # Provisions %USERPROFILE%\.wslconfig from the tracked template in the
    # repo (scripts/.wslconfig.template). Idempotent: skips if the existing
    # file already carries the managed marker. Backs up anything else.
    $target = Join-Path $env:USERPROFILE ".wslconfig"
    $marker = "# managed-by: wsl-setup"
    $templateUrl = "https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/scripts/.wslconfig.template"

    if ((Test-Path $target) -and (Select-String -Path $target -Pattern $marker -Quiet)) {
        Write-Host "Existing .wslconfig already managed by wsl-setup — leaving it in place." -ForegroundColor DarkGray
        return
    }

    try {
        $content = Invoke-WebRequest -UseBasicParsing -Uri $templateUrl | Select-Object -ExpandProperty Content
    } catch {
        Write-Host ("Falha ao baixar .wslconfig.template de {0}: {1}" -f $templateUrl, $_.Exception.Message) -ForegroundColor Red
        exit 1
    }

    if (Test-Path $target) {
        $backup = "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item $target $backup
        Write-Host ("Backed up existing .wslconfig to {0}" -f $backup) -ForegroundColor DarkGray
    }

    Set-Content -Path $target -Value $content -Encoding ASCII
    Write-Host ".wslconfig provisioned at $target (restart WSL to apply)." -ForegroundColor Green
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

$targetExists = $existingDistros -contains $targetDistro
if ($bootstrapMode -eq "replace-existing" -and -not $targetExists) {
    Write-Host "replace-existing is unavailable because $targetDistroLabel was not detected in preflight state." -ForegroundColor Red
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
        $backupTaken = Invoke-WslDistroBackup -DistroName $targetDistro
        $backupNote = if ($backupTaken) { "a backup was exported" } else { "NO backup was taken" }

        $confirmation = Read-Host "Confirm replace of the existing Ubuntu distro with $targetDistro ($backupNote)? [Y/N]"
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

Install-WslConfig

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
