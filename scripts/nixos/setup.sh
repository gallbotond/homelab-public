#!/usr/bin/env nix-shell
#!nix-shell -i bash -p samba git openssh coreutils findutils

set -euo pipefail

# ------------------------------------------------------------------------------
# Environment & dependency checks
# ------------------------------------------------------------------------------

if [[ -z "${IN_NIX_SHELL:-}" ]]; then
  cat >&2 <<'EOF'
[error] This script must be run inside nix-shell.

Example:
  nix-shell -p samba git openssh coreutils findutils --run \
  "curl -fsSL https://github.com/gallbotond/homelab-public/raw/refs/heads/main/scripts/nixos/setup.sh | bash"

Or:
  curl -LO https://github.com/gallbotond/homelab-public/raw/refs/heads/main/scripts/nixos/setup.sh
  chmod +x setup.sh
  nix-shell -p samba git openssh coreutils findutils --run "./setup.sh"
EOF
  exit 1
fi

missing=0
for cmd in smbclient git ssh ssh-add find mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[error] Required command not found: $cmd" >&2
    missing=1
  fi
done

if [[ $missing -eq 1 ]]; then
  cat >&2 <<'EOF'

[error] One or more required tools are missing.

Make sure you entered nix-shell with:
  nix-shell -p samba git openssh coreutils findutils

EOF
  exit 1
fi


# ------------------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------------------
log()  { printf "[setup] %s\n" "$*"; }
warn() { printf "[warn] %s\n" "$*"; }
err()  { printf "[error] %s\n" "$*"; exit 1; }

# ------------------------------------------------------------------------------
# Defaults / Config
# ------------------------------------------------------------------------------
SMB_SERVER="192.168.1.100"
SMB_SHARE="Secrets"
SMB_PATH="SSH keys/gallbotond.local"

SMB_USER="secret"
SMB_PASS=""
NON_INTERACTIVE=0

GIT_REPO_SSH="git@github.com:gallbotond/homelab.git"
SSH_HOST="github.com"

# ------------------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --smb-server)      SMB_SERVER="$2"; shift 2;;
    --share)           SMB_SHARE="$2"; shift 2;;
    --share-path)      SMB_PATH="$2"; shift 2;;
    --smb-user)        SMB_USER="$2"; shift 2;;
    --smb-pass)        SMB_PASS="$2"; shift 2;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    -h|--help)
      echo "Usage: $0 [--smb-user USER] [--smb-pass PASS] [--non-interactive]"
      exit 0
      ;;
    *) shift;;
  esac
done

# ------------------------------------------------------------------------------
# Credentials
# ------------------------------------------------------------------------------
[[ -z "$SMB_USER" && $NON_INTERACTIVE -eq 0 ]] && read -rp "SMB username: " SMB_USER

if [[ -z "$SMB_PASS" && $NON_INTERACTIVE -eq 0 ]]; then
  prompt_password() {
    local prompt="$1"
    local var
    if [[ -t 0 ]]; then
      # stdin is a tty
      printf "%s" "$prompt"
      stty -echo
      read -r var
      stty echo
      printf "\n"
    else
      # stdin is NOT a tty (curl | bash)
      read -rsp "$prompt" var </dev/tty
      printf "\n" >/dev/tty
    fi
    printf "%s" "$var"
  }

SMB_PASS="$(prompt_password "SMB password: ")"

fi

[[ -z "$SMB_USER" || -z "$SMB_PASS" ]] && err "SMB credentials not provided"

log "Connecting to //$SMB_SERVER/$SMB_SHARE"
log "Remote path: $SMB_PATH"

# ------------------------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------------------------
SSH_DIR="$HOME/.ssh"
GIT_DIR="$HOME/Git"
SSH_CONFIG="$SSH_DIR/config"

mkdir -p "$SSH_DIR" "$GIT_DIR"
chmod 700 "$SSH_DIR"

# ------------------------------------------------------------------------------
# Fetch files from SMB into temp dir
# ------------------------------------------------------------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Fetching SSH keys via smbclient"

(
  cd "$TMP_DIR"
  smbclient "//$SMB_SERVER/$SMB_SHARE" \
    -U "${SMB_USER}%${SMB_PASS}" \
    -c "cd \"$SMB_PATH\"; recurse; prompt; mget *"
) || err "Failed to fetch files from SMB share"

# ------------------------------------------------------------------------------
# Install SSH keys (idempotent)
# ------------------------------------------------------------------------------
found_keys=0

while IFS= read -r -d '' key; do
  dst="$SSH_DIR/$(basename "$key")"
  if [[ ! -f "$dst" ]]; then
    mv "$key" "$dst"
    chmod 600 "$dst"
    log "Installed private key: $(basename "$dst")"
  fi
  found_keys=1
done < <(find "$TMP_DIR" -type f -name "id_*" ! -name "*.pub" -print0)

while IFS= read -r -d '' key; do
  dst="$SSH_DIR/$(basename "$key")"
  if [[ ! -f "$dst" ]]; then
    mv "$key" "$dst"
    chmod 644 "$dst"
    log "Installed public key: $(basename "$dst")"
  fi
  found_keys=1
done < <(find "$TMP_DIR" -type f -name "*.pub" -print0)

[[ $found_keys -eq 0 ]] && warn "No SSH keys found"

# ------------------------------------------------------------------------------
# SSH config (idempotent)
# ------------------------------------------------------------------------------
if [[ ! -f "$SSH_CONFIG" ]] || ! grep -q "Host $SSH_HOST" "$SSH_CONFIG"; then
  log "Updating ~/.ssh/config"
  {
    echo
    echo "Host $SSH_HOST"
    echo "  User git"
    echo "  AddKeysToAgent yes"
    echo "  IdentityFile $SSH_DIR/id_rsa"
  } >> "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

# ------------------------------------------------------------------------------
# SSH agent (best-effort)
# ------------------------------------------------------------------------------
if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi

ssh-add "$SSH_DIR"/id_* >/dev/null 2>&1 || true

# ------------------------------------------------------------------------------
# Clone repo (idempotent)
# ------------------------------------------------------------------------------
cd "$GIT_DIR"
REPO_NAME="$(basename "$GIT_REPO_SSH" .git)"

if [[ -d "$REPO_NAME/.git" ]]; then
  log "Repository already exists: $REPO_NAME"
else
  log "Cloning repository"
  git clone "$GIT_REPO_SSH"
fi

log "Setup complete ✅"
