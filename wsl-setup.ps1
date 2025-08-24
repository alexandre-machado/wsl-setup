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