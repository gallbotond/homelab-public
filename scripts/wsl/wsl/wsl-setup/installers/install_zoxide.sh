#!/usr/bin/env bash
set -euo pipefail


log() { printf "[zoxide] %s\n" "$*"; }


if command -v zoxide >/dev/null 2>&1; then
log "zoxide already installed."
exit 0
fi


log "Installing zoxide..."
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
log "zoxide installation complete."