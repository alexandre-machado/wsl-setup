wsl --help > $null 2>&1
# Verifica WSL via winget e instala se não encontrado
$wslList = winget list --id Microsoft.WSL 2>&1 | Out-String
if ($wslList -match 'No installed package found matching input criteria' -or $wslList -notmatch 'Microsoft\.WSL') {
	Write-Host "WSL (Microsoft.WSL) não encontrado. Instalando via winget..." -ForegroundColor Yellow
	winget install --id Microsoft.WSL --exact --accept-package-agreements --accept-source-agreements
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Falha ao instalar WSL via winget. Tente manualmente: winget install --id Microsoft.WSL --exact" -ForegroundColor Red
		exit 1
	}
	Write-Host "WSL instalado via winget." -ForegroundColor Green
}

wsl --update
wsl --unregister Ubuntu-24.04
wsl --install Ubuntu-24.04
wsl --set-default Ubuntu-24.04

write-host "1/2 WSL on Windows is installed." -ForegroundColor Green

# Prompt for Git variables
$defaultGitName = "Alexandre Machado"
$defaultGitEmail = "alexandre@machado.cc"

$GIT_NAME = Read-Host "Enter your name for Git [$defaultGitName]"
if ([string]::IsNullOrWhiteSpace($GIT_NAME)) { $GIT_NAME = $defaultGitName }

$GIT_EMAIL = Read-Host "Enter your email for Git [$defaultGitEmail]"
if ([string]::IsNullOrWhiteSpace($GIT_EMAIL)) { $GIT_EMAIL = $defaultGitEmail }

wsl ~ -e bash -lc "echo 'Starting WSL setup...' && \
export GIT_NAME='$GIT_NAME' && \
export GIT_EMAIL='$GIT_EMAIL' && \
git clone https://github.com/alexandre-machado/wsl-setup.git && \
chmod 700 wsl-setup/ -R && \
cd wsl-setup && \
./setup.sh"

write-host "2/2 WSL on Windows is set up" -ForegroundColor Green