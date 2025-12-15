#!/usr/bin/env bash
set -euo pipefail

# ============================
# Pre-flight checks
# ============================
if [[ "$(id -u)" -eq 0 ]]; then
  err "Do not run this script as root or with sudo. Run as a normal user."
fi

# Ensure required tools for asdf plugin installation
REQUIRED_PACKAGES=(unzip curl git)
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
        log "Installing missing dependency: $pkg"
        sudo apt update
        sudo apt install -y "$pkg"
    fi
done



# ============================
# Configuration
# ============================
# Change this to your repo root where scripts live
REPO_RAW_BASE="https://raw.githubusercontent.com/gallbotond/homelab-public/main/scripts/wsl/wsl-setup"


# Temporary working directory
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT


# ============================
# Utilities
# ============================
log()    { printf "\033[1;34m[INF]\033[0m %s\n" "$*"; }
warn()   { printf "\033[1;33m[WAR]\033[0m %s\n" "$*" >&2; }
err()    { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; exit 1; }
run()    { log "$*"; eval "$*"; }


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

# Make brew immediately available
log "Configuring Homebrew for current shell session"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Ensure persistent PATH for future shells
log "Ensuring Homebrew is in PATH for future shell sessions"
grep -qxF 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' ~/.bashrc || \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc

log "Installing asdf and plugins..."
fetch_and_run "installers/install_asdf.sh"
fetch_and_run "installers/install_asdf_plugins.sh" terraform terragrunt

log "Configuring ssh keys..."
fetch_and_run "smb/fetch_keys.sh" "${ARGS[@]}"


# SSH test (writes detected username to stdout)
GITHUB_USER="$(fetch_and_run "ssh/test_github_ssh.sh" || true)"


fetch_and_run "git/clone_repos.sh" "$GITHUB_USER" "${ARGS[@]}"


log "WSL setup complete."