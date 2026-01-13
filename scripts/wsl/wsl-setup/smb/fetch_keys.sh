#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------------------
log() { printf "[smb] %s\n" "$*"; }
warn() { printf "[smb-warn] %s\n" "$*"; }
err() {
	printf "[smb-error] %s\n" "$*"
	exit 1
}

# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------
SMB_SERVER="truenas-scale"
SMB_SHARE="Secrets"
SMB_USER="secret"
SMB_PASS=""
SMB_PATH="."
NON_INTERACTIVE=0

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
	case "$1" in
	--smb-server)
		SMB_SERVER="$2"
		shift 2
		;;
	--share)
		SMB_SHARE="$2"
		shift 2
		;;
	--share-path)
		SMB_PATH="$2"
		shift 2
		;;
	--smb-user)
		SMB_USER="$2"
		shift 2
		;;
	--smb-pass)
		SMB_PASS="$2"
		shift 2
		;;
	--non-interactive)
		NON_INTERACTIVE=1
		shift
		;;
	*) shift ;;
	esac
done

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
if ! command -v smbclient >/dev/null 2>&1; then
	log "Installing smbclient..."
	if command -v apt >/dev/null 2>&1; then
		sudo apt update -y && sudo apt install -y smbclient
	elif command -v dnf >/dev/null 2>&1; then
		sudo dnf install -y samba-client
	else
		err "No supported package manager found"
	fi
fi

# ------------------------------------------------------------------------------
# Credentials
# ------------------------------------------------------------------------------
if [[ -z "$SMB_PASS" && $NON_INTERACTIVE -eq 0 ]]; then
	printf "SMB password: "
	stty -echo
	read -r SMB_PASS
	stty echo
	printf "\n"
fi

[[ -z "$SMB_PASS" ]] && err "SMB password not provided"

log "Connecting to //$SMB_SERVER/$SMB_SHARE as $SMB_USER"
log "Remote path: $SMB_PATH"

# ------------------------------------------------------------------------------
# Prepare ~/.ssh
# ------------------------------------------------------------------------------
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# ------------------------------------------------------------------------------
# Download files into a temp directory
# ------------------------------------------------------------------------------
TMP_DIR="$(mktemp -d)"
log "Using temporary directory: $TMP_DIR"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

(
	cd "$TMP_DIR"
	smbclient "//$SMB_SERVER/$SMB_SHARE" \
		-U "${SMB_USER}%${SMB_PASS}" \
		-c "cd \"$SMB_PATH\"; recurse; prompt; mget *"
) || err "Failed to fetch files from SMB share"

# ------------------------------------------------------------------------------
# Move SSH keys into ~/.ssh (flatten structure)
# ------------------------------------------------------------------------------
log "Processing SSH keys..."

found_keys=0

# Private keys
while IFS= read -r -d '' key; do
	dst="$SSH_DIR/$(basename "$key")"
	mv "$key" "$dst"
	chmod 600 "$dst"
	log "Installed private key: $(basename "$dst")"
	found_keys=1
done < <(find "$TMP_DIR" -type f -name "id_*" ! -name "*.pub" -print0)

# Public keys
while IFS= read -r -d '' key; do
	dst="$SSH_DIR/$(basename "$key")"
	mv "$key" "$dst"
	chmod 644 "$dst"
	log "Installed public key: $(basename "$dst")"
	found_keys=1
done < <(find "$TMP_DIR" -type f -name "*.pub" -print0)

if [[ $found_keys -eq 0 ]]; then
	warn "No SSH keys found"
else
	log "SSH keys successfully installed into ~/.ssh"
fi

log "SSH key fetch complete."
