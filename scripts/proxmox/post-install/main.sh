#!/usr/bin/env bash

set -euo pipefail

POST_INSTALL_URL="https://raw.githubusercontent.com/gallbotond/homelab-public/main/scripts/proxmox/post-install/post-install-args.sh"
DEFAULT_POST_INSTALL_ARGS=(
	--fix-sources
	--disable-enterprise
	--enable-no-sub
	--fix-ceph
	# --add-pvetest
	--disable-nag
	--enable-ha
	--update
)

POST_INSTALL_ARGS=("$@")

if [[ ${#POST_INSTALL_ARGS[@]} -eq 0 ]]; then
	POST_INSTALL_ARGS=("${DEFAULT_POST_INSTALL_ARGS[@]}")
fi

# nag-buster
bash <(curl -fsSL "https://raw.githubusercontent.com/foundObjects/pve-nag-buster/refs/heads/master/install.sh")

# post install script
bash <(curl -fsSL "$POST_INSTALL_URL") "${POST_INSTALL_ARGS[@]}"

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
