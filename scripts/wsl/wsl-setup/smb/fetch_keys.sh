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
KEYS_CSV=""
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
    --keys) KEYS_CSV="$2"; shift 2;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    *) shift;;
  esac
done

# --------------------
# Dependencies
# --------------------
if ! command -v smbclient >/dev/null; then
  log "Installing smbclient..."
  if command -v apt >/dev/null; then
    sudo apt update -y && sudo apt install -y smbclient
  elif command -v dnf >/dev/null; then
    sudo dnf install -y samba-client
  else
    err "No supported package manager found"
  fi
fi

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
# List directories
# --------------------
log "Listing available folders (advanced)..."

raw_ls=$(smbclient "//$SMB_SERVER/$SMB_SHARE" \
  -U "${SMB_USER}%${SMB_PASS}" \
  -c "ls" 2>/dev/null) || err "SMB listing failed"

# mapfile -t folders < <(
#   echo "$raw_ls" |
#   awk '$2 == "D" && $1 != "." && $1 != ".." { print substr($0, 1, index($0, "D") - 1) }' |
#   sed 's/[[:space:]]*$//'
# )
mapfile -t folders < <(
  echo "$raw_ls" |
  awk '
    /^[[:space:]]*\./ { next }          # skip . and ..
    /[[:space:]]D[[:space:]]/ {
      name = substr($0, 1, index($0, " D") - 1)
      sub(/[[:space:]]+$/, "", name)
      print name
    }
  '
)


[[ ${#folders[@]} -eq 0 ]] && err "No folders found in share"

log "Available folders:"
for i in "${!folders[@]}"; do
  printf "  [%d] %s\n" "$((i+1))" "${folders[$i]}"
done

# --------------------
# Folder selection
# --------------------
if [[ -z "$SMB_PATH" && $NON_INTERACTIVE -eq 0 ]]; then
  while true; do
    choice="$(read_tty "Select folder number (or empty for root): ")"

    [[ -z "$choice" ]] && { SMB_PATH="."; break; }

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#folders[@]} )); then
      SMB_PATH="${folders[$((choice-1))]}"
      break
    fi

    warn "Invalid selection. Please enter a number between 1 and ${#folders[@]}"
  done
fi

log "Selected folder: '$SMB_PATH'"

# --------------------
# List files
# --------------------
log "Listing files in '$SMB_PATH'..."

raw_files=$(smbclient "//$SMB_SERVER/$SMB_SHARE" \
  -U "${SMB_USER}%${SMB_PASS}" \
  -c "cd $SMB_PATH; ls" 2>/dev/null) || err "Failed to list files"

mapfile -t files < <(
  echo "$raw_files" |
  awk '$2 != "D" && $1 != "." && $1 != ".." { print substr($0, 1, index($0, $2) - 1) }' |
  sed 's/[[:space:]]*$//'
)

if [[ ${#files[@]} -eq 0 ]]; then
  warn "No files found in '$SMB_PATH'"
  exit 0
fi

log "Files found:"
for f in "${files[@]}"; do
  printf "  - %s\n" "$f"
done

# --------------------
# Select files
# --------------------
selected=()
if [[ -n "$KEYS_CSV" ]]; then
  IFS=',' read -ra selected <<< "$KEYS_CSV"
elif [[ $NON_INTERACTIVE -eq 0 ]]; then
  read -rp "Which files to copy (comma-separated or 'all')? " pick
  if [[ "$pick" == "all" ]]; then
    selected=("${files[@]}")
  else
    IFS=',' read -ra selected <<< "$pick"
  fi
else
  selected=("${files[@]}")
fi

# --------------------
# Copy files
# --------------------
for key in "${selected[@]}"; do
  key="$(echo "$key" | xargs)"

  src="//$SMB_SERVER/$SMB_SHARE/$SMB_PATH/$key"
  dst="$HOME/.ssh/$key"

  log "Copying:"
  log "  FROM: $src"
  log "  TO:   $dst"

  smbclient "//$SMB_SERVER/$SMB_SHARE" \
    -U "${SMB_USER}%${SMB_PASS}" \
    -c "cd $SMB_PATH; get $key $dst" >/dev/null \
    || warn "Failed to copy $key"

  if [[ "$key" =~ \.pub$ ]]; then
    chmod 644 "$dst"
  else
    chmod 600 "$dst"
  fi
done

log "SSH key fetch complete."
