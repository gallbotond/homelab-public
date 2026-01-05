#!/usr/bin/env nix-shell
#!nix-shell -i bash -p cifs-utils git openssh coreutils

set -euo pipefail

### ---------------------------
### CONFIG
### ---------------------------

SMB_SERVER="//192.168.1.100/Secrets"          # e.g. //nas/secrets
SMB_KEY_PATH="/SSH keys/gallbotond.local/"             # path inside SMB share
GIT_REPO_SSH="git@github.com:gallbotond/homelab.git"

SSH_KEY_NAME="id_rsa"
SSH_HOST="github.com"

### ---------------------------
### ARGUMENT PARSING
### ---------------------------

SMB_USER=""
SMB_PASS=""

usage() {
  echo "Usage: $0 [-u smb_user] [-p smb_password]"
  exit 1
}

while getopts "u:p:h" opt; do
  case "$opt" in
    u) SMB_USER="$OPTARG" ;;
    p) SMB_PASS="$OPTARG" ;;
    h) usage ;;
  esac
done

if [[ -z "$SMB_USER" ]]; then
  read -rp "SMB username: " SMB_USER
fi

if [[ -z "$SMB_PASS" ]]; then
  read -srp "SMB password: " SMB_PASS
  echo
fi

### ---------------------------
### PATHS
### ---------------------------

GIT_DIR="$HOME/Git"
SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/$SSH_KEY_NAME"
SSH_CONFIG="$SSH_DIR/config"
MOUNT_POINT="$(mktemp -d)"

cleanup() {
  sudo umount "$MOUNT_POINT" 2>/dev/null || true
  rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

### ---------------------------
### DIRECTORY SETUP (idempotent)
### ---------------------------

mkdir -p "$GIT_DIR"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

### ---------------------------
### SSH KEY SETUP (idempotent)
### ---------------------------

if [[ ! -f "$SSH_KEY" ]]; then
  echo "▶ SSH key not found, mounting SMB share"

  sudo mount -t cifs "$SMB_SERVER" "$MOUNT_POINT" \
    -o "username=$SMB_USER,password=$SMB_PASS,ro"

  echo "▶ Copying SSH key"
  cp "$MOUNT_POINT/$SMB_KEY_PATH" "$SSH_KEY"
  chmod 600 "$SSH_KEY"

  if [[ -f "$MOUNT_POINT/$SMB_KEY_PATH.pub" ]]; then
    cp "$MOUNT_POINT/$SMB_KEY_PATH.pub" "$SSH_KEY.pub"
    chmod 644 "$SSH_KEY.pub"
  fi
else
  echo "✔ SSH key already exists, skipping copy"
fi

### ---------------------------
### SSH CONFIG (idempotent)
### ---------------------------

if [[ ! -f "$SSH_CONFIG" ]] || ! grep -q "Host $SSH_HOST" "$SSH_CONFIG"; then
  echo "▶ Updating ~/.ssh/config"

  {
    echo
    echo "Host $SSH_HOST"
    echo "  User git"
    echo "  IdentityFile $SSH_KEY"
    echo "  AddKeysToAgent yes"
  } >> "$SSH_CONFIG"

  chmod 600 "$SSH_CONFIG"
else
  echo "✔ SSH config already contains $SSH_HOST"
fi

### ---------------------------
### SSH AGENT (best-effort)
### ---------------------------

if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi

ssh-add "$SSH_KEY" >/dev/null 2>&1 || true

### ---------------------------
### GIT CLONE (idempotent)
### ---------------------------

cd "$GIT_DIR"

REPO_NAME="$(basename "$GIT_REPO_SSH" .git)"

if [[ -d "$REPO_NAME/.git" ]]; then
  echo "✔ Repository already exists: $REPO_NAME"
else
  echo "▶ Cloning repository"
  git clone "$GIT_REPO_SSH"
fi

echo "✅ Setup complete"
