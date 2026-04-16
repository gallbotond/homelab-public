#!/usr/bin/env bash

WEBUI_SERVICES=(pvedaemon pveproxy)
HEALTH_SERVICES=(pvedaemon pveproxy corosync pve-cluster)

resolve_dead_node() {
	local dead_node="${1:-}"

	if [[ -z "$dead_node" ]]; then
		info "Detecting cluster members..."
		printf "\n"
		pvecm nodes 2>/dev/null || true
		printf "\n"
		read -rp "Enter the name of the DEAD/failed node to remove: " dead_node </dev/tty
	fi

	if [[ -z "$dead_node" ]]; then
		fatal "No node name provided. Exiting."
	fi

	printf "%s\n" "$dead_node"
}

current_quorate_status() {
	pvecm status 2>/dev/null | awk '/^Quorate:/{print $2}'
}

restore_quorum() {
	banner "Step 1 - Restoring Quorum"

	local quorate
	quorate="$(current_quorate_status)"

	if [[ "$quorate" == "Yes" ]]; then
		ok "Cluster is already quorate. Skipping quorum fix."
		return
	fi

	info "Cluster is NOT quorate. Setting expected votes to 1..."
	if pvecm expected 1; then
		ok "Expected votes set to 1."
	else
		fatal "Failed to set expected votes. Check corosync status manually."
	fi

	quorate="$(current_quorate_status)"
	if [[ "$quorate" == "Yes" ]]; then
		ok "Quorum restored. VMs can now be started."
	else
		fatal "Quorum still not achieved. Investigate corosync manually."
	fi
}

remove_dead_node() {
	local dead_node="$1"
	local stale_dir="/etc/pve/nodes/${dead_node}"
	local delnode_log=""

	banner "Step 2 - Removing Dead Node: ${dead_node}"

	if pvecm nodes 2>/dev/null | grep -qw "$dead_node"; then
		info "Node '${dead_node}' found in cluster config. Removing..."
		delnode_log="$(mktemp /tmp/pvecm_delnode.XXXXXX.log)"

		if pvecm delnode "$dead_node" 2>&1 | tee "$delnode_log"; then
			ok "pvecm delnode completed."
		else
			warn "pvecm delnode returned an error. Checking if node was removed anyway..."
		fi

		if grep -Eq "CS_ERR_NOT_EXIST|Killing node" "$delnode_log" 2>/dev/null; then
			ok "Node was unreachable (expected) - removal proceeded successfully."
		fi

		rm -f "$delnode_log"
	else
		warn "Node '${dead_node}' not found in current cluster membership. It may already be removed."
	fi

	if [[ -d "$stale_dir" ]]; then
		info "Removing stale node directory: ${stale_dir}"
		rm -rf "$stale_dir"
		ok "Stale node directory removed."
	fi

	info "Verifying cluster membership after removal:"
	pvecm nodes 2>/dev/null || true
	printf "\n"
}

restart_webui_services() {
	local title="${1:-}"
	local svc

	if [[ -n "$title" ]]; then
		banner "$title"
	fi

	for svc in "${WEBUI_SERVICES[@]}"; do
		info "Restarting ${svc}..."
		if systemctl restart "$svc"; then
			ok "${svc} restarted."
		else
			warn "Failed to restart ${svc}. Check: systemctl status ${svc}"
		fi
	done
}

print_final_status() {
	local svc
	local status

	banner "Recovery Complete - Final Status"

	info "Cluster status:"
	pvecm status 2>/dev/null || true
	printf "\n"

	info "VM list:"
	qm list 2>/dev/null || warn "No VMs found or qm not available."
	printf "\n"

	info "Service health:"
	for svc in "${HEALTH_SERVICES[@]}"; do
		status="$(systemctl is-active "$svc" 2>/dev/null || printf "unknown")"
		if [[ "$status" == "active" ]]; then
			ok "${svc}: ${status}"
		else
			warn "${svc}: ${status}"
		fi
	done

	printf "\n"
	ok "Done. Try logging into the WebUI now."
	printf "\n"
}
