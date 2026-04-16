#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# shellcheck source=./lib/ui.sh
. "$LIB_DIR/ui.sh"
# shellcheck source=./lib/system_checks.sh
. "$LIB_DIR/system_checks.sh"
# shellcheck source=./lib/cluster_recovery.sh
. "$LIB_DIR/cluster_recovery.sh"
# shellcheck source=./lib/tfa.sh
. "$LIB_DIR/tfa.sh"

main() {
	require_root
	require_proxmox

	banner "Proxmox Cluster Recovery Script"

	local dead_node
	dead_node="$(resolve_dead_node "${1:-}")"

	info "Target dead node: ${BOLD}${dead_node}${RESET}"

	restore_quorum
	remove_dead_node "$dead_node"
	restart_webui_services "Step 3 - Restarting WebUI Services (fixes 2FA / login)"
	maybe_disable_tfa
	print_final_status
}

main "$@"
