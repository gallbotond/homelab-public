#!/usr/bin/env bash
set -euo pipefail

log() { printf "[asdf-plugins] %s\n" "$*"; }

# Load asdf
ASDF_PATH="$(brew --prefix asdf)/libexec/asdf.sh"
if [[ -f "$ASDF_PATH" ]]; then
  # shellcheck disable=SC1090
  . "$ASDF_PATH"
else
  echo "asdf not found" && exit 1
fi

for plugin in "$@"; do
  log "Ensuring plugin $plugin exists..."
  asdf plugin-add "$plugin" >/dev/null 2>&1 || true
  log "Installing latest $plugin..."
  latest=$(asdf list-all "$plugin" | awk 'NF' | tail -1)
  asdf install "$plugin" "$latest"
  asdf global "$plugin" "$latest"
  log "$plugin $latest installed and set global."
done
