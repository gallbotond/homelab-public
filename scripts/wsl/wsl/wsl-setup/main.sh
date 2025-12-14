#!/usr/bin/env bash
set -euo pipefail


# ============================
# Configuration
# ============================
# Change this to your repo root where scripts live
REPO_RAW_BASE="https://raw.githubusercontent.com/gallbotond/homelab-public/main/scripts/wsl/wsl"


# Temporary working directory
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT


# ============================
# Utilities
# ============================
log() { printf "
␛
[1;34m[INFO]
␛
[0m %s
" "$*"; }
warn() { printf "
␛
[1;33m[WARN]
␛
[0m %s
" "$*"; }
err() { printf "
␛
[1;31m[ERROR]
␛
[0m %s
" "$*"; exit 1; }


fetch_and_run() {
local relative_path="$1"; shift
local url="$REPO_RAW_BASE/$relative_path"
local file="$WORKDIR/$(basename "$relative_path")"


log "Fetching $url"
curl -fsSL "$url" -o "$file" || err "Failed to download $url"
chmod +x "$file"


"$file" "$@"
}


# ============================
# Main
# ============================
ARGS=("$@")
log "Starting WSL setup via remote scripts..."


fetch_and_run "installers/install_zoxide.sh"
fetch_and_run "installers/install_homebrew.sh"
fetch_and_run "installers/install_asdf.sh"
fetch_and_run "installers/install_asdf_plugins.sh" terraform terragrunt


fetch_and_run "smb/fetch_keys.sh" "${ARGS[@]}"


# SSH test (writes detected username to stdout)
GITHUB_USER="$(fetch_and_run "ssh/test_github_ssh.sh" || true)"


fetch_and_run "git/clone_repos.sh" "$GITHUB_USER" "${ARGS[@]}"


log "WSL setup complete."