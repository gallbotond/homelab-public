#!/usr/bin/env bash
set -euo pipefail

log() { printf "[asdf] %s\n" "$*"; }

if command -v asdf >/dev/null 2>&1; then
  log "asdf already installed."
  exit 0
fi

log "Installing asdf via brew..."
brew install asdf

# Load asdf now
if [[ -f "$(brew --prefix asdf)/libexec/asdf.sh" ]]; then
  # shellcheck disable=SC1090
  . "$(brew --prefix asdf)/libexec/asdf.sh"
fi

log "asdf installation complete."
