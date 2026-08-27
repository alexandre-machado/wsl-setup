<#
.SYNOPSIS
    Provisions and manages declarative WSL distros with dedicated data disk and credential persistence.

.DESCRIPTION
    Declarative Pure As-Code bootstrap orchestrator for WSL on Windows driven by wsl-profiles.json.
    - Checks and installs WSL via winget if missing.
    - Provisions %USERPROFILE%\.wslconfig from template.
    - Creates clean Linux distros (Ubuntu, Alpine, Debian, etc.) from cached official rootfs images.
    - Connects /home/ubuntu-24/repos to the dedicated ext4 data disk (e.g. D:\wsl\data\repos.vhdx).
    - Provisions each distro with its respective Git identity and developer tools via setup.sh.

.PARAMETER ConfigFile
    Explicit path to wsl-profiles.json. If omitted, searches standard locations
    including OneDrive (%OneDrive%\Projetos\WorkSpace\wsl-profiles.json), local repo,
    and falls back to wsl-profiles.template.json.

.PARAMETER DryRun
    Simulates the provisioning steps without modifying WSL distros or files.

.PARAMETER Force
    Bypasses interactive confirmation prompts (e.g. when replacing existing distros).
#>

param(
    [Alias("ConfigPath")]
    [string]$ConfigFile = $null,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-WslPackageInstalled {
    $wslList = winget list --id Microsoft.WSL 2>&1 | Out-String
    return -not ($wslList -match 'No installed package found matching input criteria' -or $wslList -notmatch 'Microsoft\.WSL')
}

function Ensure-WslPackageInstalled {
    param([bool]$WslInstalled)

    if ($WslInstalled) {
        return
    }

    if ($DryRun) {
        Write-Host "[dry-run] winget install --id Microsoft.WSL --exact --accept-package-agreements --accept-source-agreements" -ForegroundColor DarkGray
        return
    }

    Write-Host "WSL (Microsoft.WSL) not found. Installing via winget..." -ForegroundColor Yellow
    winget install --id Microsoft.WSL --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install WSL via winget. Try manually: winget install --id Microsoft.WSL --exact" -ForegroundColor Red
        exit 1
    }

    Write-Host "WSL installed via winget." -ForegroundColor Green
}

function Install-WslConfig {
    # Provisions %USERPROFILE%\.wslconfig from the tracked template in the
    # repo (scripts/.wslconfig.template). Idempotent: skips if the existing
    # file already carries the managed marker. Backs up anything else.
    $target = Join-Path $env:USERPROFILE ".wslconfig"
    $marker = "# managed-by: wsl-setup"
    $templateUrl = "https://raw.githubusercontent.com/alexandre-machado/wsl-setup/main/scripts/.wslconfig.template"

    if ((Test-Path -LiteralPath $target) -and (Select-String -Path $target -Pattern $marker -Quiet)) {
        Write-Host "Existing .wslconfig already managed by wsl-setup — leaving it in place." -ForegroundColor DarkGray
        return
    }

    # Use local template if available (e.g. running from clone)
    $localTemplate = Join-Path $PSScriptRoot "scripts" ".wslconfig.template"
    if (Test-Path -LiteralPath $localTemplate) {
        Write-Host "Installing .wslconfig from local template: $localTemplate" -ForegroundColor DarkGray
        $content = Get-Content -Raw -Path $localTemplate
    } else {
        try {
            $content = Invoke-WebRequest -UseBasicParsing -Uri $templateUrl | Select-Object -ExpandProperty Content
        } catch {
            Write-Host ("Failed to download .wslconfig.template from {0}: {1}" -f $templateUrl, $_.Exception.Message) -ForegroundColor Red
            exit 1
        }
    }

    if ($DryRun) {
        Write-Host "[dry-run] Provision .wslconfig at $target" -ForegroundColor DarkGray
        return
    }

    if (Test-Path -LiteralPath $target) {
        $backup = "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $target -Destination $backup
        Write-Host ("Backed up existing .wslconfig to {0}" -f $backup) -ForegroundColor DarkGray
    }

    Set-Content -Path $target -Value $content -Encoding ASCII
    Write-Host ".wslconfig provisioned at $target (restart WSL to apply)." -ForegroundColor Green
}

function Get-WslDistroNames {
    try {
        return @(wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    } catch {
        return @()
    }
}

function Expand-ConfigValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }
    return [Environment]::ExpandEnvironmentVariables($Value)
}

function To-Bool {
    param($Value, [bool]$Default = $false)
    if ($null -eq $Value) {
        return $Default
    }
    if ($Value -is [bool]) {
        return $Value
    }
    $raw = $Value.ToString().Trim().ToLowerInvariant()
    return $raw -in @("1", "true", "yes", "y")
}

function Get-DistroRootfsInfo {
    param(
        [string]$Distribution,
        [string]$VersionOrCodename
    )

    $dist = if ([string]::IsNullOrWhiteSpace($Distribution)) { "ubuntu" } else { $Distribution.Trim().ToLowerInvariant() }
    $ver = if ([string]::IsNullOrWhiteSpace($VersionOrCodename)) { "" } else { $VersionOrCodename.Trim().ToLowerInvariant() }

    # Custom URL directly passed
    if ($dist -like "http*" -or $ver -like "http*") {
        $url = if ($dist -like "http*") { $dist } else { $ver }
        $filename = [System.IO.Path]::GetFileName($url)
        return @{
            Distribution = "Custom"
            Version = "custom"
            Name = "Custom Linux RootFS ($url)"
            Url = $url
            CacheFile = $filename
            Family = "custom"
        }
    }

    # Debian Family: Ubuntu
    if ($dist -match "ubuntu" -or $ver -in @("noble", "jammy", "focal", "bionic", "24.04", "22.04", "20.04")) {
        $targetVer = if ($ver) { $ver } else { "24.04" }
        switch ($targetVer) {
            { $_ -in @("22.04", "jammy", "ubuntu-22.04") } {
                return @{
                    Distribution = "Ubuntu"
                    Version = "22.04"
                    Codename = "jammy"
                    Name = "Ubuntu 22.04 LTS (Jammy Jellyfish)"
                    Url = "https://cdimages.ubuntu.com/ubuntu-wsl/jammy/daily-live/current/jammy-wsl-amd64.wsl"
                    CacheFile = "jammy-wsl-amd64.wsl"
                    Family = "debian"
                }
            }
            { $_ -in @("20.04", "focal", "ubuntu-20.04") } {
                return @{
                    Distribution = "Ubuntu"
                    Version = "20.04"
                    Codename = "focal"
                    Name = "Ubuntu 20.04 LTS (Focal Fossa)"
                    Url = "https://cloud-images.ubuntu.com/wsl/focal/current/ubuntu-focal-wsl-amd64-wsl.rootfs.tar.gz"
                    CacheFile = "focal-wsl-amd64.tar.gz"
                    Family = "debian"
                }
            }
            default {
                return @{
                    Distribution = "Ubuntu"
                    Version = "24.04"
                    Codename = "noble"
                    Name = "Ubuntu 24.04 LTS (Noble Numbat)"
                    Url = "https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl"
                    CacheFile = "noble-wsl-amd64.wsl"
                    Family = "debian"
                }
            }
        }
    }

    # Debian Family: Debian GNU/Linux
    if ($dist -match "debian" -or $ver -in @("bookworm", "bullseye", "12", "11")) {
        $targetVer = if ($ver) { $ver } else { "12" }
        switch ($targetVer) {
            { $_ -in @("11", "bullseye") } {
                return @{
                    Distribution = "Debian"
                    Version = "11"
                    Codename = "bullseye"
                    Name = "Debian 11 (Bullseye)"
                    Url = "https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-amd64/bullseye/rootfs.tar.xz"
                    CacheFile = "debian-11-rootfs.tar.xz"
                    Family = "debian"
                }
            }
            default {
                return @{
                    Distribution = "Debian"
                    Version = "12"
                    Codename = "bookworm"
                    Name = "Debian 12 (Bookworm)"
                    Url = "https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-amd64/bookworm/rootfs.tar.xz"
                    CacheFile = "debian-12-rootfs.tar.xz"
                    Family = "debian"
                }
            }
        }
    }

    # Alpine Linux (Ultra-lightweight musl/busybox, ~3 MB)
    if ($dist -match "alpine" -or $ver -match "alpine") {
        $targetVer = if ($ver) { $ver } else { "3.20" }
        return @{
            Distribution = "Alpine"
            Version = $targetVer
            Codename = "alpine"
            Name = "Alpine Linux $targetVer"
            Url = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.2-x86_64.tar.gz"
            CacheFile = "alpine-minirootfs-3.20.2-x86_64.tar.gz"
            Family = "alpine"
        }
    }

    # Arch Linux
    if ($dist -match "arch") {
        return @{
            Distribution = "Arch"
            Version = "rolling"
            Codename = "rolling"
            Name = "Arch Linux (Rolling)"
            Url = "https://gitlab.archlinux.org/archlinux/archlinux-docker/-/raw/master/archlinux-rootfs.tar.gz"
            CacheFile = "archlinux-rootfs.tar.gz"
            Family = "arch"
        }
    }

    # Fedora
    if ($dist -match "fedora") {
        $targetVer = if ($ver) { $ver } else { "40" }
        return @{
            Distribution = "Fedora"
            Version = $targetVer
            Codename = "fedora"
            Name = "Fedora $targetVer (Container RootFS)"
            Url = "https://download.fedoraproject.org/pub/fedora/linux/releases/40/Container/x86_64/images/Fedora-Container-Base-Generic.x86_64-40-1.14.tar.xz"
            CacheFile = "fedora-40-rootfs.tar.xz"
            Family = "fedora"
        }
    }

    # Fallback to Ubuntu 24.04 LTS
    return @{
        Distribution = "Ubuntu"
        Version = "24.04"
        Codename = "noble"
        Name = "Ubuntu 24.04 LTS (Noble Numbat)"
        Url = "https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl"
        CacheFile = "noble-wsl-amd64.wsl"
        Family = "debian"
    }
}

function Escape-BashSingleQuoted {
    param([string]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return $Value.Replace("'", "'\''")
}

function Invoke-Checked {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    if ($DryRun) {
        Write-Host ("[dry-run] " + $Description) -ForegroundColor DarkGray
        return
    }

    Write-Host $Description -ForegroundColor Cyan
    try {
        & $Action
    } catch {
        throw "$Description failed: $_"
    }
}

function Resolve-ConfigFilePath {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $expanded = Expand-ConfigValue $ExplicitPath
        if (Test-Path -LiteralPath $expanded) {
            return (Resolve-Path -LiteralPath $expanded).Path
        }
        throw "Specified config file not found: $ExplicitPath"
    }

    $candidates = @()

    # 1. Check OneDrive locations (WorkSpace and WSL folders)
    $oneDriveRoots = @(
        $env:OneDrive,
        $env:OneDriveConsumer,
        $env:OneDriveCommercial,
        (Join-Path $env:USERPROFILE "OneDrive")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($odRoot in $oneDriveRoots) {
        $candidates += Join-Path $odRoot "Projetos\WorkSpace\wsl-profiles.json"
        $candidates += Join-Path $odRoot "WSL\wsl-profiles.json"
        $candidates += Join-Path $odRoot "wsl-profiles.json"
    }

    # 2. Local directory candidates
    $candidates += Join-Path $PSScriptRoot "wsl-profiles.json"
    $candidates += Join-Path (Get-Location).Path "wsl-profiles.json"

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    # 3. Fallback to local template if present
    $templateCandidates = @(
        (Join-Path $PSScriptRoot "wsl-profiles.template.json"),
        (Join-Path (Get-Location).Path "wsl-profiles.template.json")
    )
    foreach ($tmpl in $templateCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($tmpl) -and (Test-Path -LiteralPath $tmpl)) {
            $resolvedTmpl = (Resolve-Path -LiteralPath $tmpl).Path
            Write-Host "No custom wsl-profiles.json found; falling back to template: $resolvedTmpl" -ForegroundColor Yellow
            return $resolvedTmpl
        }
    }

    # If not found, report all searched locations and point to template
    Write-Host "No wsl-profiles.json configuration found in standard locations:" -ForegroundColor Yellow
    foreach ($c in ($candidates | Select-Object -Unique)) {
        Write-Host "  - $c" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "To configure your profiles:" -ForegroundColor Cyan
    Write-Host "  1. Copy 'wsl-profiles.template.json' to your OneDrive folder (e.g. '$env:OneDrive\Projetos\WorkSpace\wsl-profiles.json')"
    Write-Host "  2. Customize the distro names, paths, and Git identities."
    Write-Host "  3. Re-run this script."
    throw "Missing wsl-profiles.json configuration."
}

# 1. Ensure WSL core package is installed on Windows
$wslPackageInstalled = Get-WslPackageInstalled
Ensure-WslPackageInstalled -WslInstalled $wslPackageInstalled

# 2. Provision %USERPROFILE%\.wslconfig from tracked template
Install-WslConfig

# 3. Resolve configuration
$resolvedConfigPath = Resolve-ConfigFilePath -ExplicitPath $ConfigFile
Write-Host "Using profiles configuration: $resolvedConfigPath" -ForegroundColor Green

$configRaw = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding utf8
$config = $configRaw | ConvertFrom-Json

if (-not $config.distros -or $config.distros.Count -eq 0) {
    throw "Invalid config: at least one entry in 'distros' is required."
}

$setDefaultDistro = if ($config.setDefaultDistro) { $config.setDefaultDistro } else { $null }
$globalReplace = To-Bool -Value $config.replaceExisting -Default $false
$dataDiskPath = if ($config.dataDiskPath) { Expand-ConfigValue $config.dataDiskPath } else { "D:\wsl\data\repos.vhdx" }
$dataDiskMountName = if ($config.dataDiskMountName) { $config.dataDiskMountName } else { "repos" }

$cacheDir = Join-Path $env:LOCALAPPDATA "wsl\cache"
$existingDistros = Get-WslDistroNames

Write-Host ""
Write-Host "=== WSL Multi-Profile Provisioning Plan (Pure As-Code) ===" -ForegroundColor Cyan
Write-Host ("WSL Installed:      {0}" -f ($(if ($wslPackageInstalled) { "Yes" } else { "No" })))
Write-Host ("Config File:        {0}" -f $resolvedConfigPath)
Write-Host ("Data VHDX:          {0} -> /mnt/wsl/{1}" -f $dataDiskPath, $dataDiskMountName)
Write-Host "Target Profiles:"
foreach ($p in $config.distros) {
    $pDistRaw = if ($p.distribution) { $p.distribution } elseif ($p.distro) { $p.distro } elseif ($p.os) { $p.os } elseif ($config.defaultDistribution) { $config.defaultDistribution } else { "Ubuntu" }
    $pVersionRaw = if ($p.version) { $p.version } elseif ($p.release) { $p.release } elseif ($config.defaultVersion) { $config.defaultVersion } else { "" }
    $pInfo = Get-DistroRootfsInfo -Distribution $pDistRaw -VersionOrCodename $pVersionRaw
    $rawLoc = if ($p.installLocation) { $p.installLocation } else { "%LOCALAPPDATA%\wsl\$($p.name)" }
    $pLoc = Expand-ConfigValue $rawLoc
    $pExists = if ($existingDistros -contains $p.name) { "[Exists]" } else { "[New]" }
    $pName = $p.name
    $pMode = if ($p.isolated) { "Isolated Sandbox" } else { "Standard Dev" }
    Write-Host ("  - {0} {1} ({2}) [{3}] -> {4}" -f $pName, $pExists, $pInfo.Name, $pMode, $pLoc)
}
if ($setDefaultDistro) {
    Write-Host ("Default Distro:     {0}" -f $setDefaultDistro)
}
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "" 

# 4. Ensure data disk is mounted (if path is configured)
if ($dataDiskPath) {
    if (-not (Test-Path -LiteralPath $dataDiskPath)) {
        if ($DryRun) {
            Write-Host ("[dry-run] Data disk VHDX not found at '{0}' (would be required in non-dry-run mode)." -f $dataDiskPath) -ForegroundColor Yellow
        } else {
            throw "Data disk VHDX not found at '$dataDiskPath'. Create and format it first."
        }
    } else {
        $mountPoint = "/mnt/wsl/$dataDiskMountName"
        Invoke-Checked -Description "Ensuring data disk '$dataDiskPath' is mounted as '$mountPoint'" -Action {
            $mounted = wsl bash -c "mountpoint -q $mountPoint && echo YES || echo NO" 2>$null
            if ($mounted -notmatch "YES") {
                wsl --mount --vhd $dataDiskPath --name $dataDiskMountName
            }
        }
    }
}

# 5. Provision each distro profile
foreach ($profile in $config.distros) {
    if (-not $profile.name) {
        throw "Each entry in 'distros' must define 'name'."
    }

    $name = $profile.name
    $rawLoc = if ($profile.installLocation) { $profile.installLocation } else { "%LOCALAPPDATA%\wsl\$name" }
    $installLocation = Expand-ConfigValue $rawLoc
    $isIsolated = To-Bool -Value $profile.isolated -Default $false
    $mountDisk = if ($null -ne $profile.mountDataDisk) { To-Bool -Value $profile.mountDataDisk } else { -not $isIsolated }
    $profileReplace = To-Bool -Value $profile.replaceIfExists -Default $globalReplace

    $currentDistros = Get-WslDistroNames
    $exists = $currentDistros -contains $name
    if ($exists -and $profileReplace) {
        if (-not $Force -and -not $DryRun) {
            $confirm = Read-Host "Distro '$name' already exists and replace is enabled. Unregister and wipe '$name'? [Y/N]"
            if ($confirm.Trim().ToUpperInvariant() -ne "Y") {
                Write-Host "Skipping replacement of '$name' at user request." -ForegroundColor Yellow
                $profileReplace = $false
            }
        }
        if ($profileReplace) {
            Invoke-Checked -Description "Unregistering existing distro '$name'" -Action { wsl --unregister $name }
            $exists = $false
        }
    }

    # Resolve Linux distribution and rootfs image for this distro profile
    $pDistRaw = if ($profile.distribution) { $profile.distribution } elseif ($profile.distro) { $profile.distro } elseif ($profile.os) { $profile.os } elseif ($config.defaultDistribution) { $config.defaultDistribution } else { "Ubuntu" }
    $pVersionRaw = if ($profile.version) { $profile.version } elseif ($profile.release) { $profile.release } elseif ($config.defaultVersion) { $config.defaultVersion } else { "" }
    $rootfsInfo = Get-DistroRootfsInfo -Distribution $pDistRaw -VersionOrCodename $pVersionRaw
    $cachedRootfs = Join-Path $cacheDir $rootfsInfo.CacheFile

    if (-not (Test-Path -LiteralPath $cachedRootfs)) {
        if ($DryRun) {
            Write-Host ("[dry-run] Download {0} from {1} to {2}" -f $rootfsInfo.Name, $rootfsInfo.Url, $cachedRootfs) -ForegroundColor DarkGray
        } else {
            if (-not (Test-Path -LiteralPath $cacheDir)) {
                New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            }
            Write-Host ("Downloading {0} rootfs..." -f $rootfsInfo.Name) -ForegroundColor Cyan
            Invoke-WebRequest -Uri $rootfsInfo.Url -OutFile $cachedRootfs -UseBasicParsing
            Write-Host ("Downloaded and cached to {0}." -f $cachedRootfs) -ForegroundColor Green
        }
    } else {
        Write-Host ("Using cached rootfs for {0}: {1}" -f $rootfsInfo.Name, $cachedRootfs) -ForegroundColor DarkGray
    }

    if (-not $exists) {
        if ($DryRun) {
            Write-Host ("[dry-run] Ensure install directory parent exists for {0}" -f $installLocation) -ForegroundColor DarkGray
            Write-Host ("[dry-run] wsl --import {0} {1} {2} --version 2" -f $name, $installLocation, $cachedRootfs) -ForegroundColor DarkGray
        } else {
            $installParent = Split-Path -Parent $installLocation
            if (-not [string]::IsNullOrWhiteSpace($installParent)) {
                New-Item -ItemType Directory -Path $installParent -Force | Out-Null
            }
            Invoke-Checked -Description "Importing clean $($rootfsInfo.Name) distro '$name' into '$installLocation'" -Action {
                wsl --import $name $installLocation $cachedRootfs --version 2
            }
        }

        # Configure default user (ubuntu-24) with passwordless sudo & /etc/wsl.conf across distros
        $systemdVal = if ($rootfsInfo.Family -eq "alpine") { "false" } else { "true" }
        $userCmd = "if command -v apk >/dev/null 2>&1; then apk update && apk add --no-cache sudo bash shadow curl jq git ca-certificates; id -u ubuntu-24 &>/dev/null || useradd -m -s /bin/bash -u 1000 ubuntu-24 2>/dev/null || adduser -D -u 1000 -s /bin/bash ubuntu-24 2>/dev/null; addgroup ubuntu-24 wheel 2>/dev/null || true; else id -u ubuntu-24 &>/dev/null || useradd -m -s /bin/bash -u 1000 ubuntu-24; usermod -aG sudo ubuntu-24 2>/dev/null || true; fi; mkdir -p /etc/sudoers.d; echo 'ubuntu-24 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu-24; chmod 0440 /etc/sudoers.d/ubuntu-24; printf '[boot]\nsystemd=$systemdVal\n\n[user]\ndefault=ubuntu-24\n\n[network]\ngenerateResolvConf=true\n\n[interop]\nenabled=true\nappendWindowsPath=true\n' > /etc/wsl.conf"
        Invoke-Checked -Description "Configuring default user (ubuntu-24) and wsl.conf in '$name'" -Action {
            wsl -d $name -u root -e /bin/sh -c $userCmd
        }

        # Configure /etc/fstab to mount dedicated ext4 data disk by LABEL only for non-isolated profiles
        if ($dataDiskPath -and $mountDisk) {
            $fstabCmd = "mkdir -p /home/ubuntu-24/repos; if ! grep -q 'LABEL=wsl-repos' /etc/fstab 2>/dev/null; then echo 'LABEL=wsl-repos /home/ubuntu-24/repos ext4 defaults,nofail 0 0' >> /etc/fstab; fi; mount -a 2>/dev/null || true; chown -R ubuntu-24:ubuntu-24 /home/ubuntu-24"
            Invoke-Checked -Description "Configuring data disk mount (LABEL=wsl-repos) in /etc/fstab for '$name'" -Action {
                wsl -d $name -u root -e bash -c $fstabCmd
            }
        } else {
            $isolatedCmd = "mkdir -p /home/ubuntu-24/workspace; chown -R ubuntu-24:ubuntu-24 /home/ubuntu-24"
            Invoke-Checked -Description "Creating isolated local workspace for '$name' (no repos disk access)" -Action {
                wsl -d $name -u root -e bash -c $isolatedCmd
            }
        }

        # Run as-code setup inside the new distro
        if ($rootfsInfo.Family -eq "alpine") {
            # Alpine-specific ultra-fast lightweight CI/runner provisioning (~3 MB base + shasum/act/docker)
            $alpineSetupCmd = "apk update && apk add --no-cache docker-cli docker-cli-compose curl jq git bash ca-certificates coreutils perl-utils icu-libs krb5-libs zlib libstdc++ gcompat && curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin && mkdir -p /home/ubuntu-24/workspace && echo 'export PATH=/usr/local/bin:`$PATH' >> /home/ubuntu-24/.bashrc"
            Invoke-Checked -Description "Executing Alpine CI runner setup in '$name' (act, docker-cli, git, jq, shasum)" -Action {
                wsl -d $name -u root -e /bin/sh -c $alpineSetupCmd
            }
        } else {
            if ($isIsolated) {
                $asCodeSetupCmd = "export ISOLATED_PROFILE=true && export SSH_DISABLED=true && export GPG_DISABLED=true && cd /home/ubuntu-24 && if [ -d /mnt/d/repos/alexandre-machado/wsl-setup ]; then cp -r /mnt/d/repos/alexandre-machado/wsl-setup /tmp/wsl-setup && cd /tmp/wsl-setup && ./setup.sh --only apps,network-tuning,wsl-conf,dotfiles,npm; else git clone https://github.com/alexandre-machado/wsl-setup.git && cd wsl-setup && ./setup.sh --only apps,network-tuning,wsl-conf,dotfiles,npm; fi"
            } else {
                $gitName = Escape-BashSingleQuoted $profile.gitName
                $gitEmail = Escape-BashSingleQuoted $profile.gitEmail
                $asCodeSetupCmd = "export GIT_NAME='$gitName' && export GIT_EMAIL='$gitEmail' && cd /home/ubuntu-24 && if [ -d /mnt/d/repos/alexandre-machado/wsl-setup ]; then cd /mnt/d/repos/alexandre-machado/wsl-setup && ./setup.sh; else git clone https://github.com/alexandre-machado/wsl-setup.git && cd wsl-setup && ./setup.sh; fi"
            }
            Invoke-Checked -Description "Executing As-Code setup.sh inside '$name' (Dotfiles, Zsh, Tmux, Apps)" -Action {
                wsl -d $name -u ubuntu-24 -e bash -lc $asCodeSetupCmd
            }
        }
    } else {
        Write-Host ("Distro '{0}' already exists. Skipping import and initial provisioning." -f $name) -ForegroundColor DarkGray
    }
}

if ($setDefaultDistro) {
    Invoke-Checked -Description "Setting default distro to '$setDefaultDistro'" -Action { wsl --set-default $setDefaultDistro }
}

Write-Host ""
Write-Host "=== WSL Multi-Profile Provisioning Completed Successfully ===" -ForegroundColor Green
Write-Host "Next steps for Docker Desktop:" -ForegroundColor Cyan
Write-Host "  1. Open Docker Desktop"
Write-Host "  2. Go to: Settings > Resources > WSL Integration"
Write-Host "  3. Enable integration for your new distros:"
foreach ($profile in $config.distros) {
    $pName = $profile.name
    Write-Host ("     [x] {0}" -f $pName) -ForegroundColor White
}
Write-Host "  4. Click 'Apply & restart'"
Write-Host ""
