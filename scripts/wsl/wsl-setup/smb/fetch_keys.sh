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

# Prompt for required fields if not provided
[[ -z "$SMB_SERVER" && $NON_INTERACTIVE -eq 0 ]] && SMB_SERVER="$(read_tty "SMB server: ")"
[[ -z "$SMB_SHARE"  && $NON_INTERACTIVE -eq 0 ]] && SMB_SHARE="$(read_tty "SMB share: ")"
[[ -z "$SMB_USER"   && $NON_INTERACTIVE -eq 0 ]] && SMB_USER="$(read_tty "SMB username: ")"

# TTY-safe SMB password prompt
if [[ $NON_INTERACTIVE -eq 0 && -z "$SMB_PASS" ]]; then
  if [[ -t 0 ]]; then
    printf "SMB password: "
    stty -echo
    read -r SMB_PASS
    stty echo
    printf "\n"
  else
    printf "SMB password: " > /dev/tty
    stty -echo < /dev/tty
    read -r SMB_PASS < /dev/tty
    stty echo < /dev/tty
    printf "\n" > /dev/tty
  fi
fi

# Non-interactive check
if [[ $NON_INTERACTIVE -eq 1 && -z "$SMB_PASS" ]]; then
  err "SMB password must be provided in non-interactive mode"
fi

# Validate required variables
for v in SMB_SERVER SMB_SHARE SMB_USER SMB_PASS; do
  if [[ -z "${!v}" ]]; then
    err "$v is required but not set"
  fi
done

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"


# --- Interactive folder selection ---

# List top-level directories/files in the share
log "Listing top-level directories on //$SMB_SERVER/$SMB_SHARE ..."
top_level=$(smbclient //"$SMB_SERVER"/"$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "ls" 2>/dev/null) || err "SMB listing failed"

echo "$top_level" | awk '/^[ ]+[^ ]/ {print $1}'

if [[ $NON_INTERACTIVE -eq 0 ]]; then
  SMB_PATH="$(read_tty "Enter folder to fetch keys from (or leave empty for root): ")"
fi

# Default to root if empty
[[ -z "$SMB_PATH" ]] && SMB_PATH="."

# --- List files in chosen path ---
log "Listing files in '$SMB_PATH' ..."
# Quote folder path for smbclient to handle spaces
list=$(smbclient //"$SMB_SERVER"/"$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "cd \"$SMB_PATH\"; ls" 2>/dev/null) || err "SMB listing failed"

# Parse files (allow spaces)
mapfile -t files < <(echo "$list" | awk '/^[ ]+[A-Za-z0-9_.-]+/ {for(i=1;i<=NF;i++){if($i ~ /^[A-Za-z0-9_.-]+$/){print $i}}} ')

# Select which keys to copy
selected=()
if [[ -n "$KEYS_CSV" ]]; then
  IFS=',' read -ra selected <<< "$KEYS_CSV"
elif [[ $NON_INTERACTIVE -eq 0 ]]; then
  read -rp "Which keys to copy (comma-separated or 'all')? " pick
  if [[ "$pick" == "all" ]]; then
    selected=("${files[@]}")
  else
    IFS=',' read -ra selected <<< "$pick"
  fi
else
  selected=("${files[@]}")
fi

# Fetch the selected keys
for key in "${selected[@]}"; do
  key_trim=$(echo "$key" | sed 's/^ *//;s/ *$//')
  log "Fetching '$key_trim' ..."
  smbclient //"$SMB_SERVER"/"$SMB_SHARE" -U "${SMB_USER}%${SMB_PASS}" -c "cd \"$SMB_PATH\"; get \"$key_trim\" \"$HOME/.ssh/$key_trim\"" >/dev/null 2>&1 || log "Failed to fetch $key_trim"
  if [[ "$key_trim" =~ \.pub$ ]]; then chmod 644 "$HOME/.ssh/$key_trim"; else chmod 600 "$HOME/.ssh/$key_trim"; fi
done


log "Finished fetching keys."
