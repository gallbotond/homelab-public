#!/usr/bin/env bash
set -euo pipefail

log() { printf "[homebrew] %s\n" "$*"; }

if command -v brew >/dev/null 2>&1; then
  log "Homebrew already installed."
  exit 0
fi

log "Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Activate brew in this environment
if [[ -d "$HOME/.linuxbrew" ]]; then
  eval "$($HOME/.linuxbrew/bin/brew shellenv)"
elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

log "Homebrew installation complete."

