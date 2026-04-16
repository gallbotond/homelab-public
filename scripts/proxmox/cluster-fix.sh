#!/usr/bin/env bash
# =============================================================================
# proxmox-cluster-fix.sh
# Recovers a Proxmox node after a cluster peer failure:
#   1. Restores quorum on the surviving node
#   2. Removes the dead node from the cluster
#   3. Restarts WebUI daemons (fixes 2FA / login issues)
#   4. Optionally disables 2FA on the node by backing up the TFA config
# Usage: sudo bash proxmox-cluster-fix.sh [dead-node-name]
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
banner() {
	echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"
	echo -e "${BOLD}${CYAN}  $*${RESET}"
	echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}\n"
}

# ── Root check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
	error "This script must be run as root. Try: sudo bash $0"
	exit 1
fi

# ── Proxmox check ─────────────────────────────────────────────────────────────
if ! command -v pvecm &>/dev/null; then
	error "pvecm not found. Is this a Proxmox VE node?"
	exit 1
fi

banner "Proxmox Cluster Recovery Script"

# ── Determine dead node name ──────────────────────────────────────────────────
DEAD_NODE="${1:-}"

if [[ -z "$DEAD_NODE" ]]; then
	info "Detecting cluster members..."
	echo ""
	pvecm nodes 2>/dev/null || true
	echo ""
	read -rp "Enter the name of the DEAD/failed node to remove: " DEAD_NODE </dev/tty
fi

if [[ -z "$DEAD_NODE" ]]; then
	error "No node name provided. Exiting."
	exit 1
fi

info "Target dead node: ${BOLD}${DEAD_NODE}${RESET}"

# ── Step 1: Restore quorum ────────────────────────────────────────────────────
banner "Step 1 — Restoring Quorum"

QUORATE=$(pvecm status 2>/dev/null | awk '/^Quorate:/{print $2}')

if [[ "$QUORATE" == "Yes" ]]; then
	ok "Cluster is already quorate. Skipping quorum fix."
else
	info "Cluster is NOT quorate. Setting expected votes to 1..."
	if pvecm expected 1; then
		ok "Expected votes set to 1."
	else
		error "Failed to set expected votes. Check corosync status manually."
		exit 1
	fi

	# Verify
	QUORATE=$(pvecm status 2>/dev/null | awk '/^Quorate:/{print $2}')
	if [[ "$QUORATE" == "Yes" ]]; then
		ok "Quorum restored. VMs can now be started."
	else
		error "Quorum still not achieved. Investigate corosync manually."
		exit 1
	fi
fi

# ── Step 2: Remove dead node ──────────────────────────────────────────────────
banner "Step 2 — Removing Dead Node: ${DEAD_NODE}"

# Check if node still appears in cluster
if pvecm nodes 2>/dev/null | grep -qw "$DEAD_NODE"; then
	info "Node '${DEAD_NODE}' found in cluster config. Removing..."
	if pvecm delnode "$DEAD_NODE" 2>&1 | tee /tmp/pvecm_delnode.log; then
		ok "pvecm delnode completed."
	else
		warn "pvecm delnode returned an error. Checking if node was removed anyway..."
	fi

	# CS_ERR_NOT_EXIST is expected and harmless when node is truly offline
	if grep -q "CS_ERR_NOT_EXIST\|Killing node" /tmp/pvecm_delnode.log 2>/dev/null; then
		ok "Node was unreachable (expected) — removal proceeded successfully."
	fi
else
	warn "Node '${DEAD_NODE}' not found in current cluster membership. It may already be removed."
fi

# Clean up stale node directory from /etc/pve/nodes/
STALE_DIR="/etc/pve/nodes/${DEAD_NODE}"
if [[ -d "$STALE_DIR" ]]; then
	info "Removing stale node directory: ${STALE_DIR}"
	rm -rf "$STALE_DIR"
	ok "Stale node directory removed."
fi

# Verify node is gone
info "Verifying cluster membership after removal:"
pvecm nodes 2>/dev/null || true
echo ""

# ── Step 3: Restart WebUI daemons ─────────────────────────────────────────────
banner "Step 3 — Restarting WebUI Services (fixes 2FA / login)"

for svc in pvedaemon pveproxy; do
	info "Restarting ${svc}..."
	if systemctl restart "$svc"; then
		ok "${svc} restarted."
	else
		warn "Failed to restart ${svc}. Check: systemctl status ${svc}"
	fi
done

# ── Step 4 (optional): Disable 2FA on the node ───────────────────────────────
banner "Step 4 — Optional: Disable 2FA on This Node"

TFA_CONFIG="/etc/pve/priv/tfa.cfg"

read -rp "Disable Proxmox 2FA on this node by backing up ${TFA_CONFIG}? (y/N): " DISABLE_TFA

if [[ "$DISABLE_TFA" =~ ^[Yy]$ ]]; then
	if [[ -f "$TFA_CONFIG" ]]; then
		TFA_BACKUP="${TFA_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
		info "Backing up 2FA config to ${TFA_BACKUP}"
		cp "$TFA_CONFIG" "$TFA_BACKUP"
		: >"$TFA_CONFIG"
		ok "2FA disabled on this node."
		warn "Restore ${TFA_BACKUP} or re-enroll users after confirming WebUI access is stable."

		for svc in pvedaemon pveproxy; do
			info "Restarting ${svc} to apply 2FA change..."
			if systemctl restart "$svc"; then
				ok "${svc} restarted."
			else
				warn "Failed to restart ${svc}. Check: systemctl status ${svc}"
			fi
		done
	else
		warn "2FA config not found at ${TFA_CONFIG}. It may already be disabled."
	fi
else
	info "Skipping 2FA disable step."
fi

# ── Final status ──────────────────────────────────────────────────────────────
banner "Recovery Complete — Final Status"

info "Cluster status:"
pvecm status 2>/dev/null || true
echo ""

info "VM list:"
qm list 2>/dev/null || warn "No VMs found or qm not available."
echo ""

info "Service health:"
for svc in pvedaemon pveproxy corosync pve-cluster; do
	STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
	if [[ "$STATUS" == "active" ]]; then
		ok "${svc}: ${STATUS}"
	else
		warn "${svc}: ${STATUS}"
	fi
done

echo ""
ok "Done. Try logging into the WebUI now."
echo ""
