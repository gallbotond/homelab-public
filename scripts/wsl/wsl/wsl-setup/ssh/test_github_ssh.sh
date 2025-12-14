############################################################
# File: ssh/test_github_ssh.sh
############################################################
#!/usr/bin/env bash
set -euo pipefail

log() { printf "[ssh-test] %s\n" "$*"; }
warn() { printf "[ssh-test-warn] %s\n" "$*"; }

GITHUB_USER_FILE="$(cd "$(dirname "$0")" && pwd)/github_user.txt"
rm -f "$GITHUB_USER_FILE"

private_keys=($(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" -printf "%f\n"))
[[ ${#private_keys[@]} -eq 0 ]] && warn "No private keys found." && exit 0

key="${private_keys[0]}"
log "Testing SSH key: $key"

set +e
result=$(ssh -i "$HOME/.ssh/$key" -o BatchMode=yes -o StrictHostKeyChecking=no -T git@github.com 2>&1)
set -e

if [[ "$result" =~ ^Hi[[:space:]]([a-zA-Z0-9-]+)! ]]; then
  user="${BASH_REMATCH[1]}"
  log "Authenticated as GitHub user: $user"
  echo "$user" > "$GITHUB_USER_FILE"
else
  warn "Could not parse GitHub username. Output: $result"
fi
