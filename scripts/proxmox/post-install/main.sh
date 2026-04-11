#!/bin/bash

set -e

# nag-buster
bash <(curl -s https://raw.githubusercontent.com/foundObjects/pve-nag-buster/refs/heads/master/install.sh)

# post install script
bash <(curl -s https://raw.githubusercontent.com/Lalatenduswain/ProxmoxVE-Post-Install-Script/refs/heads/master/post-pve-install.sh)

chmod +x post-pve-install.sh
# ./post-pve-install.sh

# post install script dependencies
apt-get update
apt-get install git -y

# set up tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# set up zoxide
apt-get install zoxide -y
echo 'eval "$(zoxide init bash)"' >>~/.bashrc
# source ~/.bashrc

# install remaining tools
apt-get install btop -y


