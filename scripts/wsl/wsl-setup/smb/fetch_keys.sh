#!/usr/bin/env bash
set -euo pipefail

log() { printf "[smb] %s\n" "$*"; }
warn() { printf "[smb-warn] %s\n" "$*"; }
err() { printf "[smb-error] %s\n" "$*"; exit 1; }

read_tty() {
  local prompt="$1"
  local var
  if [[ -t 0 ]]; then
    read -rp "$prompt" var
  else
    printf "%s" "$prompt" > /dev/tty
    read -r var < /dev/tty
  fi
  printf "%s" "$var"
}

# --------------------
# Defaults
# --------------------
SMB_SERVER="192.168.1.100"
SMB_SHARE="Secrets"
SMB_USER="secret"
SMB_PASS=""
SMB_PATH=""
NON_INTERACTIVE=0

# --------------------
# Parse args
# --------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --smb-server) SMB_SERVER="$2"; shift 2;;
    --share) SMB_SHARE="$2"; shift 2;;
    --share-path) SMB_PATH="$2"; shift 2;;
    --smb-user) SMB_USER="$2"; shift 2;;
    --smb-pass) SMB_PASS="$2"; shift 2;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    *) shift;;
  esac
done

# --------------------
# Credentials
# --------------------
if [[ -z "$SMB_PASS" && $NON_INTERACTIVE -eq 0 ]]; then
  printf "SMB password: "
  stty -echo
  read -r SMB_PASS
  stty echo
  printf "\n"
fi
[[ -z "$SMB_PASS" ]] && err "SMB password not provided"

log "Connecting to //$SMB_SERVER/$SMB_SHARE as $SMB_USER"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# --------------------
# Set target folder
# --------------------
if [[ -z "$SMB_PATH" && $NON_INTERACTIVE -eq 0 ]]; then
  SMB_PATH="."  # default to root
fi

log "Selected folder: '$SMB_PATH'"

# --------------------
# Recursive fetch of SSH keys only
# --------------------
log "Fetching all SSH key files recursively from '$SMB_PATH' into ~/.ssh ..."

# Use smbclient recursive mget
tmp_dir=$(mktemp -d)
smbclient "//$SMB_SERVER/$SMB_SHARE" \
  -U "${SMB_USER}%${SMB_PASS}" \
  -c "cd \"$SMB_PATH\"; recurse; prompt; mget *" \
  -D "$tmp_dir" >/dev/null || err "Failed to fetch files"

# Move only key files into ~/.ssh and flatten structure
find "$tmp_dir" -type f \( -name "*.pub" -o -name "id_*" -o -name "id_*_*" \) | while read -r f; do
  dst="$HOME/.ssh/$(basename "$f")"
  mv "$f" "$dst"
  if [[ "$dst" =~ \.pub$ ]]; then
    chmod 644 "$dst"
  else
    chmod 600 "$dst"
  fi
  log "Copied $(basename "$f") to ~/.ssh"
done

# Clean up temporary directory
rm -rf "$tmp_dir"

log "SSH key fetch complete."
