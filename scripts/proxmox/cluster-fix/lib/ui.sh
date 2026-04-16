#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info() {
	printf "%b[INFO]%b  %s\n" "$CYAN" "$RESET" "$*"
}

ok() {
	printf "%b[OK]%b    %s\n" "$GREEN" "$RESET" "$*"
}

warn() {
	printf "%b[WARN]%b  %s\n" "$YELLOW" "$RESET" "$*" >&2
}

error() {
	printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$*" >&2
}

fatal() {
	error "$*"
	exit 1
}

banner() {
	printf "\n%b==========================================%b\n" "$BOLD$CYAN" "$RESET"
	printf "%b  %s%b\n" "$BOLD$CYAN" "$*" "$RESET"
	printf "%b==========================================%b\n\n" "$BOLD$CYAN" "$RESET"
}
