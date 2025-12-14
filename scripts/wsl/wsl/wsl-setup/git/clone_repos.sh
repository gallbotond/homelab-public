#!/usr/bin/env bash
set -euo pipefail

log() { printf "[git] %s\n" "$*"; }
warn() { printf "[git-warn] %s\n" "$*"; }

GITHUB_USER="$1"; shift || true
REPOS_CSV=""

# Parse additional args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos) REPOS_CSV="$2"; shift 2;;
    *) shift;;
  esac
done

if [[ -z "$GITHUB_USER" ]]; then
  warn "GitHub username unknown. Skipping repo cloning."
  exit 0
fi

log "Fetching repo list for $GITHUB_USER..."
json=$(curl -s "https://api.github.com/users/$GITHUB_USER/repos?per_page=200")
mapfile -t names < <(echo "$json" | grep -oP '"full_name": *"\K[^"]+')
mapfile -t urls  < <(echo "$json" | grep -oP '"ssh_url": *"\K[^"]+')

if [[ ${#names[@]} -eq 0 ]]; then
  warn "No public repos found."
  exit 0
fi

log "Found ${#names[@]} repos."
for i in "${!names[@]}"; do printf "%3d) %s\n" $((i+1)) "${names[$i]}"; done

# Determine which repos to clone
selected=()
if [[ -n "$REPOS_CSV" ]]; then
  IFS=',' read -ra requested <<< "$REPOS_CSV"
  for r in "${requested[@]}"; do
    r_trim=$(echo "$r" | sed 's/^ *//;s/ *$//')
    idx=-1
    for i in "${!names[@]}"; do
      if [[ "${names[$i]}" == "$r_trim" || "${names[$i]##*/}" == "$r_trim" ]]; then idx="$i"; break; fi
    done
    (( idx >= 0 )) && selected+=("$idx") || warn "Repo $r_trim not found"
  done
else
  read -rp "Select repos (comma-separated numbers or 'all'): " pick
  if [[ "$pick" == "all" ]]; then
    for i in "${!names[@]}"; do selected+=("$i"); done
  else
    IFS=',' read -ra nums <<< "$pick"
    for n in "${nums[@]}"; do
      n_trim=$(echo "$n" | sed 's/^ *//;s/ *$//')
      if [[ "$n_trim" =~ ^[0-9]+$ ]]; then
        idx=$((n_trim-1))
        (( idx >= 0 && idx < ${#names[@]} )) && selected+=("$idx") || warn "Invalid index $n_trim"
      fi
    done
  fi
fi

mkdir -p "$HOME/Git"
for idx in "${selected[@]}"; do
  repo="${names[$idx]}"
  url="${urls[$idx]}"
  dest="$HOME/Git/${repo##*/}"

  if [[ -d "$dest/.git" ]]; then
    log "Updating $repo..."
    (cd "$dest" && git pull)
  else
    log "Cloning $repo..."
    git clone "$url" "$dest" || warn "Clone failed for $repo"
  fi
done

log "Repo operations complete."
