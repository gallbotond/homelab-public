#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/gallbotond/homelab-public.git"
REPO_NAME="homelab-public"
TARGET_ROOT="$HOME/Git"
TARGET_DIR="$TARGET_ROOT/$REPO_NAME"

log() {
	printf "[clone] %s\n" "$*"
}

fatal() {
	printf "[clone][ERR] %s\n" "$*" >&2
	exit 1
}

ensure_git() {
	if command -v git >/dev/null 2>&1; then
		return
	fi

	log "git not found. Installing git..."

	if command -v apt-get >/dev/null 2>&1; then
		sudo apt-get update
		sudo apt-get install -y git
		return
	fi

	if command -v dnf >/dev/null 2>&1; then
		sudo dnf install -y git
		return
	fi

	if command -v yum >/dev/null 2>&1; then
		sudo yum install -y git
		return
	fi

	fatal "Unsupported package manager. Install git manually and rerun the script."
}

ensure_git

mkdir -p "$TARGET_ROOT"

if [[ -d "$TARGET_DIR/.git" ]]; then
	log "Repository already exists. Pulling latest changes into $TARGET_DIR"
	git -C "$TARGET_DIR" pull --ff-only
else
	log "Cloning $REPO_URL into $TARGET_DIR"
	git clone "$REPO_URL" "$TARGET_DIR"
fi

log "Repository is ready at $TARGET_DIR"
