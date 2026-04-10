#!/bin/bash

set -e

# nag-buster
bash <(curl -s https://raw.githubusercontent.com/foundObjects/pve-nag-buster/refs/heads/master/install.sh)

# post install script dependencies
apt-get update
apt-get install git -y

# post install script
git clone https://github.com/Lalatenduswain/ProxmoxVE-Post-Install-Script.git &&
	cd ProxmoxVE-Post-Install-Script || {
	echo "Clone/cd failed"
	exit 1
}

chmod +x post-pve-install.sh
# ./post-pve-install.sh

# set up tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# set up zoxide
apt-get install zoxide -y
echo 'eval "$(zoxide init bash)"' >>~/.bashrc
# source ~/.bashrc

# install remaining tools
apt-get install btop -y
