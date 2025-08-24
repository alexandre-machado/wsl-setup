wsl --update
wsl --unregister Ubuntu-24.04
wsl --install Ubuntu-24.04
wsl --set-default Ubuntu-24.04

write-host "1/2 WSL on Windows is installed." -ForegroundColor Green

# Prompt for Git variables
$GIT_NAME = Read-Host "Enter your name for Git"
$GIT_EMAIL = Read-Host "Enter your email for Git"

wsl ~ -e bash -c "echo 'Starting WSL setup...' && \
export GIT_NAME='$GIT_NAME' && \
export GIT_EMAIL='$GIT_EMAIL' && \
git clone https://github.com/alexandre-machado/wsl-setup.git && \
chmod 700 wsl-setup/ -R && \
cd wsl-setup && \
./setup.sh"

write-host "2/2 WSL on Windows is set up" -ForegroundColor Green