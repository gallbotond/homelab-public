#!/usr/bin/env bash
set -euo pipefail

log() { printf "[asdf-plugins] %s\n" "$*"; }

# Load asdf environment
ASDF_DIR="$(brew --prefix asdf)/libexec"
. "$ASDF_DIR/asdf.sh"

TOOLS=("terraform" "terragrunt")

for tool in "${TOOLS[@]}"; do
    log "Ensuring plugin $tool exists..."
    asdf plugin-add "$tool" || true

    log "Installing latest $tool..."
    latest_version=$(asdf latest "$tool")
    asdf install "$tool" "$latest_version"
    asdf global "$tool" "$latest_version"
done

log "asdf plugins setup complete."
