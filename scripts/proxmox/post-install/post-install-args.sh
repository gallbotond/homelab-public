#!/usr/bin/env bash

# Proxmox VE Post-Install Script
# Author: Lalatendu
# License: MIT

set -euo pipefail
shopt -s inherit_errexit nullglob

RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
CL="\033[m"
BFR="\r\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

header_info() {
	clear
	cat <<"EOF"
    ____ _    ________   ____             __     ____           __        ____
   / __ \ |  / / ____/  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / | / / __/    / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __ `/ / /
 / ____/| |/ / /___   / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
/_/     |___/_____/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/

EOF
}

msg_info() { echo -ne " ${HOLD} ${YW}${1}..."; }
msg_ok() { echo -e "${BFR} ${CM} ${GN}${1}${CL}"; }
msg_error() { echo -e "${BFR} ${CROSS} ${RD}${1}${CL}"; }

usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

If no options are given, runs interactively via whiptail menus.

Options:
  --fix-sources          Correct Proxmox VE apt sources
  --disable-enterprise   Disable pve-enterprise repository
  --enable-no-sub        Enable pve-no-subscription repository
  --fix-ceph             Correct Ceph package repositories
  --add-pvetest          Add (disabled) pvetest repository
  --disable-nag          Disable subscription nag
  --disable-ha           Disable high availability services
  --enable-ha            Enable high availability services
  --update               Run apt update + dist-upgrade
  --reboot               Reboot after completion
  --yes-to-all           Apply all of the above (except reboot and HA changes)
  -h, --help             Show this help message
EOF
	exit 0
}

# Defaults (all off)
OPT_FIX_SOURCES=false
OPT_DISABLE_ENTERPRISE=false
OPT_ENABLE_NO_SUB=false
OPT_FIX_CEPH=false
OPT_ADD_PVETEST=false
OPT_DISABLE_NAG=false
OPT_DISABLE_HA=false
OPT_ENABLE_HA=false
OPT_UPDATE=false
OPT_REBOOT=false
INTERACTIVE=true

parse_args() {
	INTERACTIVE=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--fix-sources) OPT_FIX_SOURCES=true ;;
		--disable-enterprise) OPT_DISABLE_ENTERPRISE=true ;;
		--enable-no-sub) OPT_ENABLE_NO_SUB=true ;;
		--fix-ceph) OPT_FIX_CEPH=true ;;
		--add-pvetest) OPT_ADD_PVETEST=true ;;
		--disable-nag) OPT_DISABLE_NAG=true ;;
		--disable-ha) OPT_DISABLE_HA=true ;;
		--enable-ha) OPT_ENABLE_HA=true ;;
		--update) OPT_UPDATE=true ;;
		--reboot) OPT_REBOOT=true ;;
		--yes-to-all)
			OPT_FIX_SOURCES=true
			OPT_DISABLE_ENTERPRISE=true
			OPT_ENABLE_NO_SUB=true
			OPT_FIX_CEPH=true
			OPT_ADD_PVETEST=true
			OPT_DISABLE_NAG=true
			OPT_UPDATE=true
			;;
		-h | --help) usage ;;
		*)
			echo "Unknown option: $1"
			usage
			;;
		esac
		shift
	done
}

# Ask a yes/no question — interactively via whiptail, or just return the flag value
# Usage: ask_choice <flag_value> <backtitle> <title> <description>
ask_choice() {
	local flag="$1" backtitle="$2" title="$3" desc="$4"
	if $INTERACTIVE; then
		local choice
		choice=$(whiptail --backtitle "$backtitle" --title "$title" --menu "$desc" 14 58 2 \
			"yes" " " "no" " " 3>&2 2>&1 1>&3)
		[[ "$choice" == "yes" ]]
	else
		$flag
	fi
}

clean_sources() {
	msg_info "Checking for conflicting .sources files"
	local source_files=(
		"/etc/apt/sources.list.d/debian.sources"
		"/etc/apt/sources.list.d/pve-enterprise.sources"
		"/etc/apt/sources.list.d/ceph.sources"
	)
	for file in "${source_files[@]}"; do
		if [ -f "$file" ]; then
			mv "$file" "${file}.bak"
			echo -e "\n   - Backup created: ${file}.bak"
		fi
	done
	msg_ok "Cleaned up conflicting .sources files"
}

do_fix_sources() {
	msg_info "Correcting Proxmox VE Sources"
	cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib
deb http://deb.debian.org/debian trixie-updates main contrib
deb http://security.debian.org/debian-security trixie-security main contrib
EOF
	rm -f /etc/apt/apt.conf.d/no-bookworm-firmware.conf
	echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' >/etc/apt/apt.conf.d/no-trixie-firmware.conf
	msg_ok "Corrected Proxmox VE Sources"
}

do_disable_enterprise() {
	msg_info "Disabling 'pve-enterprise' repository"
	echo "# deb https://enterprise.proxmox.com/debian/pve trixie pve-enterprise" >/etc/apt/sources.list.d/pve-enterprise.list
	msg_ok "Disabled 'pve-enterprise' repository"
}

do_enable_no_sub() {
	msg_info "Enabling 'pve-no-subscription' repository"
	echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" >/etc/apt/sources.list.d/pve-install-repo.list
	msg_ok "Enabled 'pve-no-subscription' repository"
}

do_fix_ceph() {
	msg_info "Correcting 'ceph package repositories'"
	cat <<EOF >/etc/apt/sources.list.d/ceph.list
# deb https://enterprise.proxmox.com/debian/ceph-reef trixie enterprise
# deb http://download.proxmox.com/debian/ceph-reef trixie no-subscription
# deb https://enterprise.proxmox.com/debian/ceph-squid trixie enterprise
# deb http://download.proxmox.com/debian/ceph-squid trixie no-subscription
EOF
	msg_ok "Corrected 'ceph package repositories'"
}

do_add_pvetest() {
	msg_info "Adding 'pvetest' repository (disabled)"
	echo "# deb http://download.proxmox.com/debian/pve trixie pvetest" >/etc/apt/sources.list.d/pvetest-for-beta.list
	msg_ok "Added 'pvetest' repository"
}

do_disable_nag() {
	msg_info "Disabling subscription nag"
	echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" >/etc/apt/apt.conf.d/no-nag-script
	apt --reinstall install proxmox-widget-toolkit &>/dev/null
	msg_ok "Disabled subscription nag (clear browser cache)"
}

do_update() {
	msg_info "Updating Proxmox VE (patience)"
	apt-get update &>/dev/null
	apt-get -y dist-upgrade &>/dev/null
	msg_ok "Updated Proxmox VE"
}

start_routines() {
	header_info
	clean_sources

	if ask_choice "$OPT_FIX_SOURCES" "Proxmox VE Helper Scripts" "SOURCES" "Correct Proxmox VE sources?"; then
		do_fix_sources
	else
		msg_error "Skipped: Correcting Proxmox VE Sources"
	fi

	if ask_choice "$OPT_DISABLE_ENTERPRISE" "Proxmox VE Helper Scripts" "PVE-ENTERPRISE" "Disable 'pve-enterprise' repository?"; then
		do_disable_enterprise
	else
		msg_error "Skipped: Disabling pve-enterprise"
	fi

	if ask_choice "$OPT_ENABLE_NO_SUB" "Proxmox VE Helper Scripts" "PVE-NO-SUBSCRIPTION" "Enable 'pve-no-subscription' repository?"; then
		do_enable_no_sub
	else
		msg_error "Skipped: Enabling pve-no-subscription"
	fi

	if ask_choice "$OPT_FIX_CEPH" "Proxmox VE Helper Scripts" "CEPH" "Correct Ceph package repositories?"; then
		do_fix_ceph
	else
		msg_error "Skipped: Correcting Ceph repositories"
	fi

	if ask_choice "$OPT_ADD_PVETEST" "Proxmox VE Helper Scripts" "PVETEST" "Add (disabled) 'pvetest' repository?"; then
		do_add_pvetest
	else
		msg_error "Skipped: Adding pvetest repository"
	fi

	if [[ ! -f /etc/apt/apt.conf.d/no-nag-script ]]; then
		if ask_choice "$OPT_DISABLE_NAG" "Proxmox VE Helper Scripts" "SUBSCRIPTION NAG" "Disable subscription nag?"; then
			do_disable_nag
		else
			msg_error "Skipped: Disabling subscription nag"
		fi
	fi

	# HA — mutually exclusive, only show the relevant option
	if ! systemctl is-active --quiet pve-ha-lrm; then
		if ask_choice "$OPT_ENABLE_HA" "Proxmox VE Helper Scripts" "HIGH AVAILABILITY" "Enable high availability?"; then
			msg_info "Enabling high availability"
			systemctl enable -q --now pve-ha-lrm pve-ha-crm corosync
			msg_ok "Enabled high availability"
		fi
	elif systemctl is-active --quiet pve-ha-lrm; then
		if ask_choice "$OPT_DISABLE_HA" "Proxmox VE Helper Scripts" "HIGH AVAILABILITY" "Disable high availability?"; then
			msg_info "Disabling high availability"
			systemctl disable -q --now pve-ha-lrm pve-ha-crm corosync
			msg_ok "Disabled high availability"
		fi
	fi

	if ask_choice "$OPT_UPDATE" "Proxmox VE Helper Scripts" "UPDATE" "Update Proxmox VE now?"; then
		do_update
	else
		msg_error "Skipped: Update"
	fi

	if ask_choice "$OPT_REBOOT" "Proxmox VE Helper Scripts" "REBOOT" "Reboot Proxmox VE now? (recommended)"; then
		msg_info "Rebooting Proxmox VE"
		msg_ok "Completed Post Install Routines"
		sleep 2
		reboot
	else
		msg_error "Skipped: Reboot (recommended)"
		msg_ok "Completed Post Install Routines"
	fi
}

# ── Entry point ──────────────────────────────────────────────────────────────

if [[ $# -gt 0 ]]; then
	parse_args "$@"
else
	# Interactive mode — confirm before running
	header_info
	echo -e "\nThis script will perform Post Install Routines.\n"
	while true; do
		read -rp "Start the Proxmox VE Post Install Script (y/n)? " yn
		case $yn in
		[Yy]*) break ;;
		[Nn]*)
			clear
			exit
			;;
		*) echo "Please answer yes or no." ;;
		esac
	done
fi

if ! pveversion | grep -Eq "pve-manager/9\."; then
	msg_error "This version of Proxmox Virtual Environment is not supported"
	echo -e "Requires Proxmox Virtual Environment Version 9.0 or later.\nExiting..."
	sleep 2
	exit 1
fi

start_routines
