#!/usr/bin/env bash

require_root() {
	if [[ $EUID -ne 0 ]]; then
		fatal "This script must be run as root. Try: sudo bash $0"
	fi
}

require_proxmox() {
	if ! command -v pvecm >/dev/null 2>&1; then
		fatal "pvecm not found. Is this a Proxmox VE node?"
	fi
}
