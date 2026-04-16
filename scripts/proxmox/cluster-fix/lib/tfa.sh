#!/usr/bin/env bash

TFA_CONFIG="/etc/pve/priv/tfa.cfg"

maybe_disable_tfa() {
	local disable_tfa
	local tfa_backup

	banner "Step 4 - Optional: Disable 2FA on This Node"

	read -rp "Disable Proxmox 2FA on this node by backing up ${TFA_CONFIG}? (y/N): " disable_tfa </dev/tty

	if [[ ! "$disable_tfa" =~ ^[Yy]$ ]]; then
		info "Skipping 2FA disable step."
		return
	fi

	if [[ ! -f "$TFA_CONFIG" ]]; then
		warn "2FA config not found at ${TFA_CONFIG}. It may already be disabled."
		return
	fi

	tfa_backup="${TFA_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
	info "Backing up 2FA config to ${tfa_backup}"
	cp "$TFA_CONFIG" "$tfa_backup"
	: >"$TFA_CONFIG"
	ok "2FA disabled on this node."
	warn "Restore ${tfa_backup} or re-enroll users after confirming WebUI access is stable."

	restart_webui_services "Step 4 - Restarting WebUI Services After 2FA Disable"
}
