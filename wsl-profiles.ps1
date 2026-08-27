<#
.SYNOPSIS
    Provisions and manages multi-profile WSL distros 100% As-Code with dedicated data disk and credential persistence.

.DESCRIPTION
    Creates clean, isolated Ubuntu WSL distros (e.g. Ubuntu-Personal, Ubuntu-CloudHumans)
    from the official minimal Ubuntu 24.04 WSL rootfs (~380 MB), provisions each distro via setup.sh
    with its respective Git identity and persistent credentials (SSH/GCM), and connects
    /home/ubuntu-24/repos directly to the dedicated ext4 data disk (D:\wsl\data\repos.vhdx).

.PARAMETER ConfigPath
    Explicit path to wsl-profiles.json. If omitted, searches standard locations
    including OneDrive (%OneDrive%\Projetos\WorkSpace\wsl-profiles.json) and local repo.

.PARAMETER DryRun
    Simulates the provisioning steps without modifying WSL distros or files.

.PARAMETER Force
    Bypasses interactive confirmation prompts (e.g. when replacing existing distros).
#>

param(
    [string]$ConfigPath = $null,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

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
        [string]$VersionOrCodename
    )

    $v = if ([string]::IsNullOrWhiteSpace($VersionOrCodename)) { "24.04" } else { $VersionOrCodename.Trim().ToLowerInvariant() }

    switch ($v) {
        { $_ -in @("24.04", "noble", "ubuntu-24.04", "ubuntu-24", "lts", "latest") } {
            return @{
                Version = "24.04"
                Codename = "noble"
                Name = "Ubuntu 24.04 LTS (Noble Numbat)"
                Url = "https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl"
                CacheFile = "noble-wsl-amd64.wsl"
            }
        }
        { $_ -in @("22.04", "jammy", "ubuntu-22.04", "ubuntu-22") } {
            return @{
                Version = "22.04"
                Codename = "jammy"
                Name = "Ubuntu 22.04 LTS (Jammy Jellyfish)"
                Url = "https://cdimages.ubuntu.com/ubuntu-wsl/jammy/daily-live/current/jammy-wsl-amd64.wsl"
                CacheFile = "jammy-wsl-amd64.wsl"
            }
        }
        { $_ -in @("20.04", "focal", "ubuntu-20.04", "ubuntu-20") } {
            return @{
                Version = "20.04"
                Codename = "focal"
                Name = "Ubuntu 20.04 LTS (Focal Fossa)"
                Url = "https://cloud-images.ubuntu.com/wsl/focal/current/ubuntu-focal-wsl-amd64-wsl.rootfs.tar.gz"
                CacheFile = "focal-wsl-amd64.tar.gz"
            }
        }
        default {
            if ($v -like "http*") {
                $filename = [System.IO.Path]::GetFileName($v)
                return @{
                    Version = "custom"
                    Codename = "custom"
                    Name = "Custom Linux Rootfs ($v)"
                    Url = $v
                    CacheFile = $filename
                }
            }
            return @{
                Version = "24.04"
                Codename = "noble"
                Name = "Ubuntu 24.04 LTS (Noble Numbat)"
                Url = "https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl"
                CacheFile = "noble-wsl-amd64.wsl"
            }
        }
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

    # If not found, report all searched locations and point to template
    Write-Host "No wsl-profiles.json configuration found in standard locations:" -ForegroundColor Yellow
    foreach ($c in ($candidates | Select-Object -Unique)) {
        Write-Host "  - $c" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "To configure your profiles:" -ForegroundColor Cyan
    Write-Host "  1. Copy 'wsl-profiles.json.template' to your OneDrive folder (e.g. '$env:OneDrive\Projetos\WorkSpace\wsl-profiles.json')"
    Write-Host "  2. Customize the distro names, paths, and Git identities."
    Write-Host "  3. Re-run this script."
    throw "Missing wsl-profiles.json configuration."
}

$resolvedConfigPath = Resolve-ConfigFilePath -ExplicitPath $ConfigPath
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
Write-Host "Data VHDX:          $dataDiskPath -> /mnt/wsl/$dataDiskMountName"
Write-Host "Target Profiles:"
foreach ($p in $config.distros) {
    $pVersionRaw = if ($p.version) { $p.version } elseif ($p.release) { $p.release } elseif ($config.defaultVersion) { $config.defaultVersion } else { "24.04" }
    $pInfo = Get-DistroRootfsInfo -VersionOrCodename $pVersionRaw
    $rawLoc = if ($p.installLocation) { $p.installLocation } else { "%LOCALAPPDATA%\wsl\$($p.name)" }
    $pLoc = Expand-ConfigValue $rawLoc
    $pExists = if ($existingDistros -contains $p.name) { "[Exists]" } else { "[New]" }
    $pName = $p.name
    $pMode = if ($p.isolated) { "Isolated Sandbox" } else { "Standard Dev" }
    Write-Host "  - $pName $pExists ($($pInfo.Name)) [$pMode] -> $pLoc"
}
if ($setDefaultDistro) {
    Write-Host "Default Distro:     $setDefaultDistro"
}
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "" 

# Ensure data disk is mounted
if ($dataDiskPath) {
    if (-not (Test-Path -LiteralPath $dataDiskPath)) {
        throw "Data disk VHDX not found at '$dataDiskPath'. Create and format it first."
    }
    $mountPoint = "/mnt/wsl/$dataDiskMountName"
    Invoke-Checked -Description "Ensuring data disk '$dataDiskPath' is mounted as '$mountPoint'" -Action {
        $mounted = wsl bash -c "mountpoint -q $mountPoint && echo YES || echo NO" 2>$null
        if ($mounted -notmatch "YES") {
            wsl --mount --vhd $dataDiskPath --name $dataDiskMountName
        }
    }
}

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

    # Resolve rootfs image for this distro profile
    $pVersionRaw = if ($profile.version) { $profile.version } elseif ($profile.release) { $profile.release } elseif ($config.defaultVersion) { $config.defaultVersion } else { "24.04" }
    $rootfsInfo = Get-DistroRootfsInfo -VersionOrCodename $pVersionRaw
    $cachedRootfs = Join-Path $cacheDir $rootfsInfo.CacheFile

    if (-not (Test-Path -LiteralPath $cachedRootfs)) {
        if ($DryRun) {
            Write-Host "[dry-run] Download $($rootfsInfo.Name) from $($rootfsInfo.Url) to $cachedRootfs" -ForegroundColor DarkGray
        } else {
            if (-not (Test-Path -LiteralPath $cacheDir)) {
                New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            }
            Write-Host "Downloading $($rootfsInfo.Name) rootfs (~380 MB)..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $rootfsInfo.Url -OutFile $cachedRootfs -UseBasicParsing
            Write-Host "Downloaded and cached to $cachedRootfs." -ForegroundColor Green
        }
    } else {
        Write-Host "Using cached rootfs for $($rootfsInfo.Name): $cachedRootfs" -ForegroundColor DarkGray
    }

    if (-not $exists) {
        if ($DryRun) {
            Write-Host "[dry-run] Ensure install directory parent exists for $installLocation" -ForegroundColor DarkGray
            Write-Host "[dry-run] wsl --import $name $installLocation $cachedRootfs --version 2" -ForegroundColor DarkGray
        } else {
            $installParent = Split-Path -Parent $installLocation
            if (-not [string]::IsNullOrWhiteSpace($installParent)) {
                New-Item -ItemType Directory -Path $installParent -Force | Out-Null
            }
            Invoke-Checked -Description "Importing clean $($rootfsInfo.Name) distro '$name' into '$installLocation'" -Action {
                wsl --import $name $installLocation $cachedRootfs --version 2
            }
        }

        # Configure default user (ubuntu-24) with passwordless sudo & /etc/wsl.conf (single-line commands to avoid CRLF issues)
        $userCmd = "id -u ubuntu-24 &>/dev/null || useradd -m -s /bin/bash -u 1000 ubuntu-24; usermod -aG sudo ubuntu-24 2>/dev/null || true; echo 'ubuntu-24 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu-24; chmod 0440 /etc/sudoers.d/ubuntu-24; printf '[boot]\nsystemd=true\n\n[user]\ndefault=ubuntu-24\n\n[network]\ngenerateResolvConf=true\n\n[interop]\nenabled=true\nappendWindowsPath=true\n' > /etc/wsl.conf"
        Invoke-Checked -Description "Configuring default user (ubuntu-24) and systemd in '$name'" -Action {
            wsl -d $name -u root -e bash -c $userCmd
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

        # Run as-code setup.sh inside the new distro
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
    } else {
        Write-Host "Distro '$name' already exists. Skipping import and initial provisioning." -ForegroundColor DarkGray
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
    Write-Host "     [x] $pName" -ForegroundColor White
}
Write-Host "  4. Click 'Apply & restart'"
Write-Host ""
