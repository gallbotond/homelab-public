#!/usr/bin/env bash
set -euo pipefail

log() { printf "[homebrew] %s\n" "$*"; }
err() { printf "[homebrew][ERR] %s\n" "$*" >&2; exit 1; }

if [[ "$(id -u)" -eq 0 ]]; then
  err "Homebrew must not be installed as root"
fi

if command -v brew >/dev/null 2>&1; then
  log "Homebrew already installed."
  exit 0
fi

log "Installing Homebrew (may require sudo password)..."

# Ensure we have a TTY for sudo prompts
if [[ ! -t 0 ]]; then
  log "Re-running Homebrew installer with TTY attached"
  exec </dev/tty
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ensure Homebrew is available in this shell session
if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
else
  err "Homebrew installed but brew binary not found"
fi

log "Homebrew installation complete."
