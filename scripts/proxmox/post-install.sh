#!/bin/bash

# nag-buster
bash <(curl -s https://raw.githubusercontent.com/foundObjects/pve-nag-buster/refs/heads/master/install.sh)

# post install script dependencies
apt-get update
apt-get install git -y

# post install script
git clone https://github.com/Lalatenduswain/ProxmoxVE-Post-Install-Script.git
cd ProxmoxVE-Post-Install-Script

chmod +x post-pve-install.sh
# ./post-pve-install.sh
