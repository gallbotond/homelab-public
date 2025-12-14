############################################################
# File: smb/fetch_keys.sh
############################################################
#!/usr/bin/env bash
set -euo pipefail

log() { printf "[smb] %s\n" "$*"; }
err() { printf "[smb-error] %s\n" "$*"; exit 1; }

# Default values
SMB_SERVER=""
SMB_SHARE=""
SMB_PATH=""
SMB_USER=""
SMB_PASS=""
KEYS_CSV=""
NON_INTERACTIVE=0

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --smb-server) SMB_SERVER="$2"; shift 2;;
    --share) SMB_SHARE="$2"; shift 2;;
    --share-path) SMB_PATH="$2"; shift 2;;
    --smb-user) SMB_USER="$2"; shift 2;;
    --smb-pass) SMB_PASS="$2"; shift 2;;
    --keys) KEYS_CSV="$2"; shift 2;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    *) shift;;
  esac
done

# Install smbclient if not present
if ! command -v smbclient >/dev/null; then
  log "Installing smbclient..."
  if command -v apt >/dev/null; then sudo apt update -y && sudo apt install -y smbclient
  elif command -v dnf >/dev/null; then sudo dnf install -y samba-client
  fi
fi

[[ -z "$SMB_SERVER" ]] && [[ $NON_INTERACTIVE -eq 0 ]] && read -rp "SMB server: " SMB_SERVER
[[ -z "$SMB_SHARE" ]] && [[ $NON_INTERACTIVE -eq 0 ]] && read -rp "SMB share: " SMB_SHARE
[[ -z "$SMB_USER" ]] && [[ $NON_INTERACTIVE -eq 0 ]] && read -rp "SMB username: " SMB_USER
[[ -z "$SMB_PASS" ]] && [[ $NON_INTERACTIVE -eq 0 ]] && { printf "SMB password: "; stty -echo; read -r SMB_PASS; stty echo; printf "\n"; }

log "Listing files on SMB share..."
list=$(smbclient //"$SMB_SERVER"/"$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "ls $SMB_PATH" 2>/dev/null) || err "SMB listing failed"

files=($(echo "$list" | awk '/^[ ]+[A-Za-z0-9_.-]+/ {print $1}'))

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

# Determine which keys to fetch
selected=()
if [[ -n "$KEYS_CSV" ]]; then
  IFS=',' read -ra selected <<< "$KEYS_CSV"
else
  read -rp "Which keys to copy (comma-separated or 'all')? " pick
  if [[ "$pick" == "all" ]]; then
    selected=("${files[@]}")
  else
    IFS=',' read -ra selected <<< "$pick"
  fi
fi

for key in "${selected[@]}"; do
  key_trim=$(echo "$key" | sed 's/^ *//;s/ *$//')
  log "Fetching $key_trim..."
  smbclient //"$SMB_SERVER"/"$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "cd $SMB_PATH; get $key_trim $HOME/.ssh/$key_trim" >/dev/null 2>&1 || log "Failed to fetch $key_trim"
  if [[ "$key_trim" =~ \.pub$ ]]; then chmod 644 "$HOME/.ssh/$key_trim"; else chmod 600 "$HOME/.ssh/$key_trim"; fi
done

log "Finished fetching keys."
