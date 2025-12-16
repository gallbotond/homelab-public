#!/usr/bin/env bash
set -euo pipefail

log() { printf "[smb] %s\n" "$*"; }
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

# Interactive prompts
[[ -z "$SMB_SERVER" && $NON_INTERACTIVE -eq 0 ]] && SMB_SERVER="$(read_tty "SMB server: ")"
[[ -z "$SMB_SHARE"  && $NON_INTERACTIVE -eq 0 ]] && SMB_SHARE="$(read_tty "SMB share: ")"
[[ -z "$SMB_USER"   && $NON_INTERACTIVE -eq 0 ]] && SMB_USER="$(read_tty "SMB username: ")"

# SMB password prompt
if [[ -z "$SMB_PASS" && $NON_INTERACTIVE -eq 0 ]]; then
  printf "SMB password: "
  stty -echo
  read -r SMB_PASS
  stty echo
  printf "\n"
fi

for v in SMB_SERVER SMB_SHARE SMB_USER SMB_PASS; do
  if [[ -z "${!v}" ]]; then
    err "$v is required but not set"
  fi
done

# List top-level directories
log "Listing top-level directories on //$SMB_SERVER/$SMB_SHARE ..."
top_dirs=$(smbclient "//$SMB_SERVER/$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "ls" 2>/dev/null | awk '/D[ ]+$/ {print substr($0, index($0,$1))}')
echo "$top_dirs"

# Ask user which folder to fetch keys from
if [[ $NON_INTERACTIVE -eq 0 ]]; then
  SMB_PATH="$(read_tty "Enter folder to fetch keys from (or leave empty for root): ")"
fi

# Prepare path for smbclient (quote it to handle spaces)
if [[ -n "$SMB_PATH" ]]; then
  SMB_PATH_ESCAPED="\"$SMB_PATH\""
else
  SMB_PATH_ESCAPED="."
fi

log "Listing files in '$SMB_PATH' ..."
files=$(smbclient "//$SMB_SERVER/$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "cd $SMB_PATH_ESCAPED; ls" 2>/dev/null | awk '/^[ ]+[A-Za-z0-9_.-]+/ {print $1}')

if [[ -z "$files" ]]; then
  err "No files found in '$SMB_PATH' or listing failed"
fi

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

# Determine which keys to fetch
selected=()
if [[ -n "$KEYS_CSV" ]]; then
  IFS=',' read -ra selected <<< "$KEYS_CSV"
else
  read -rp "Which keys to copy (comma-separated or 'all')? " pick
  if [[ "$pick" == "all" ]]; then
    selected=($files)
  else
    IFS=',' read -ra selected <<< "$pick"
  fi
fi

for key in "${selected[@]}"; do
  key_trim=$(echo "$key" | sed 's/^ *//;s/ *$//')
  log "Fetching $key_trim..."
  smbclient "//$SMB_SERVER/$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "cd $SMB_PATH_ESCAPED; get \"$key_trim\" \"$HOME/.ssh/$key_trim\"" >/dev/null 2>&1 || log "Failed to fetch $key_trim"
  if [[ "$key_trim" =~ \.pub$ ]]; then chmod 644 "$HOME/.ssh/$key_trim"; else chmod 600 "$HOME/.ssh/$key_trim"; fi
done

log "Finished fetching keys."
