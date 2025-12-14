#!/usr/bin/env bash
# wsl-setup.sh
# Senior-quality installer/script to:
#  - install zoxide
#  - install Homebrew, asdf (via Homebrew)
#  - use asdf to install latest terraform and terragrunt and set global versions
#  - connect to an SMB network share containing SSH keys, let user choose keys to copy
#  - test chosen SSH key against GitHub
#  - list GitHub repositories for that SSH-authenticated account and prompt to clone into ~/Git/
#
# Usage:
#   ./wsl-setup.sh [--smb-server srv] [--share share] [--share-path path]
#                 [--smb-user user] [--smb-pass pass] [--keys "id_rsa,id_ed25519.pub"]
#                 [--repos "repo1,repo2"] [--provider github|gitlab|bitbucket] [--non-interactive]
#
# NOTE: Be careful passing passwords on the command line (they can be visible in process listings).
# Prefer interactive mode if concerned about that.

set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Utility functions
# ----------------------------
log()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn()   { printf "\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
err()    { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }
run()    { log "$*"; eval "$*"; }

# Quiet read (no echo) for passwords
read_hidden() {
  local prompt="$1"
  local varname="$2"
  printf "%s: " "$prompt" >&2
  stty -echo
  read -r "$varname"
  stty echo
  printf "\n" >&2
}

# Ensure a package is installed via detected package manager
detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  else
    echo ""
  fi
}

ensure_pkg() {
  local pkg="$1"
  if command -v "$pkg" >/dev/null 2>&1; then
    log "Package '$pkg' already installed."
    return 0
  fi

  local pm
  pm=$(detect_pkg_manager)
  if [[ -z "$pm" ]]; then
    warn "No supported package manager detected (apt/dnf). Please install $pkg manually."
    return 1
  fi

  case "$pm" in
    apt)
      log "Installing $pkg via apt (requires sudo)..."
      sudo apt-get update -y
      sudo apt-get install -y "$pkg"
      ;;
    dnf)
      log "Installing $pkg via dnf (requires sudo)..."
      sudo dnf install -y "$pkg"
      ;;
    *)
      warn "Unsupported package manager: $pm. Please install $pkg manually."
      return 1
      ;;
  esac
}

# Safe prompt with default
prompt_default() {
  local prompt="$1"
  local default="$2"
  local var
  read -rp "$prompt [$default]: " var
  echo "${var:-$default}"
}

# ----------------------------
# Argument parsing
# ----------------------------
SMB_SERVER=""
SMB_SHARE=""
SMB_PATH=""       # optional subpath in share where keys live
SMB_USER=""
SMB_PASS=""
KEYS_CSV=""
REPOS_CSV=""
PROVIDER="github"
NON_INTERACTIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smb-server) SMB_SERVER="$2"; shift 2 ;;
    --share) SMB_SHARE="$2"; shift 2 ;;
    --share-path) SMB_PATH="$2"; shift 2 ;;
    --smb-user) SMB_USER="$2"; shift 2 ;;
    --smb-pass) SMB_PASS="$2"; shift 2 ;;
    --keys) KEYS_CSV="$2"; shift 2 ;;
    --repos) REPOS_CSV="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) 
      cat <<'USAGE'
Usage: wsl-setup.sh [options]

Options:
  --smb-server <host>     SMB server hostname or IP (where SSH keys are stored)
  --share <share>         SMB share name (e.g. keys)
  --share-path <path>     Optional path inside the share (e.g. users/alice/.ssh)
  --smb-user <user>       SMB username
  --smb-pass <pass>       SMB password (WARNING: visible in process list)
  --keys "a,b,c"          Comma-separated list of key filenames to copy (e.g. id_rsa,id_ed25519.pub)
  --repos "owner/repo,..." Comma-separated repos to clone (skips listing)
  --provider <github|gitlab|bitbucket>  Git provider to interact with (default: github)
  --non-interactive       Do not prompt for confirmations (attempt to use provided values)
  -h, --help              Show this help
USAGE
      exit 0 ;;
    *)
      warn "Unknown option: $1"
      shift ;;
  esac
done

# ----------------------------
# Main tasks
# ----------------------------
install_zoxide() {
  if command -v zoxide >/dev/null 2>&1; then
    log "zoxide already present."
    return
  fi
  log "Installing zoxide..."
  # from the docs (user supplied)
  /bin/sh -c 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
  log "zoxide installed. You may need to add initialization to your shell rc."
}

install_homebrew_and_asdf() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make brew available in current shell if possible
    if [[ -d "$HOME/.linuxbrew" ]]; then
      eval "$("$HOME/.linuxbrew/bin/brew" shellenv)" || true
    elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" || true
    fi
  else
    log "Homebrew already installed."
  fi

  if ! command -v asdf >/dev/null 2>&1; then
    log "Installing asdf via brew..."
    brew install asdf || {
      warn "brew install asdf failed; trying git install"
      # fallback
      git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1 || true
      . "$HOME/.asdf/asdf.sh" || true
    }
  else
    log "asdf already installed."
  fi

  # Source asdf into this shell so following asdf commands work
  if [[ -f "$HOME/.asdf/asdf.sh" ]]; then
    # shellcheck disable=SC1090
    . "$HOME/.asdf/asdf.sh"
  else
    # try brew location
    ASDF_PATH="$(brew --prefix asdf 2>/dev/null || true)"
    if [[ -n "$ASDF_PATH" && -f "$ASDF_PATH/libexec/asdf.sh" ]]; then
      # shellcheck disable=SC1090
      . "$ASDF_PATH/libexec/asdf.sh"
    fi
  fi

  if ! command -v asdf >/dev/null 2>&1; then
    warn "asdf is not available after install; please check installation and re-run script."
    exit 1
  fi
  log "asdf is ready."
}

install_asdf_latest() {
  local plugin="$1"
  if ! asdf plugin-list | grep -q "^${plugin}\$"; then
    log "Adding asdf plugin: $plugin"
    asdf plugin-add "$plugin" || warn "plugin-add failed for $plugin (it may already exist)."
  fi

  # Try to find the latest version using asdf list-all
  log "Retrieving list of versions for $plugin..."
  local all
  all=$(asdf list-all "$plugin" 2>/dev/null || true)
  if [[ -z "$all" ]]; then
    warn "Could not retrieve version list for $plugin. Trying 'latest' alias (may or may not work)."
    asdf install "$plugin" latest || err "Failed to install latest $plugin"
    asdf global "$plugin" latest
    return 0
  fi

  # find last non-empty line (some plugins list entries with additional variants)
  local latest
  latest=$(printf "%s\n" "$all" | awk 'NF' | tail -n1)
  if [[ -z "$latest" ]]; then
    warn "Could not determine latest version for $plugin from list; trying 'latest' alias."
    asdf install "$plugin" latest || err "Failed to install latest $plugin"
    asdf global "$plugin" latest
    return 0
  fi

  log "Installing $plugin version $latest via asdf..."
  asdf install "$plugin" "$latest"
  asdf global "$plugin" "$latest"
  log "$plugin $latest installed and set globally."
}

# Use smbclient to list and retrieve keys without mounting
fetch_keys_via_smb() {
  if ! command -v smbclient >/dev/null 2>&1; then
    log "smbclient not present; attempting to install..."
    ensure_pkg "smbclient"
  fi

  if [[ -z "$SMB_SERVER" ]]; then
    if [[ $NON_INTERACTIVE -eq 1 ]]; then err "SMB server required in non-interactive mode (--smb-server)"; fi
    read -rp "SMB server (hostname or IP): " SMB_SERVER
  fi
  if [[ -z "$SMB_SHARE" ]]; then
    if [[ $NON_INTERACTIVE -eq 1 ]]; then err "SMB share required in non-interactive mode (--share)"; fi
    read -rp "SMB share name (e.g. keys): " SMB_SHARE
  fi
  if [[ -z "$SMB_USER" ]]; then
    read -rp "SMB username: " SMB_USER
  fi
  if [[ -z "$SMB_PASS" ]]; then
    read_hidden "SMB password (input hidden)" SMB_PASS
  fi

  local remote_path="."
  if [[ -n "${SMB_PATH:-}" ]]; then
    remote_path="$SMB_PATH"
  fi

  log "Connecting to smb://${SMB_SERVER}/${SMB_SHARE} and listing files in '${remote_path}'..."
  # List files in path
  local list_out
  # Use 'smbclient //server/share -U user%pass -c "ls path"' and capture output
  list_out=$(smbclient //"${SMB_SERVER}"/"${SMB_SHARE}" -U "${SMB_USER}%${SMB_PASS}" -c "cd ${remote_path}; ls" 2>/dev/null) || {
    err "Failed to list files on SMB share. Check server/share/credentials."
  }

  # Parse listing for filenames (smbclient 'ls' shows at least filename columns)
  local files
  files=()
  while IFS= read -r line; do
    # Lines that look like: "  file.txt           A   1234  Thu Jul  1 12:00:00 2021"
    # We'll take first whitespace-separated token
    # skip lines that are not file lines
    if [[ "$line" =~ ^\s+[A-Za-z0-9\._-]+ ]]; then
      name=$(echo "$line" | awk '{print $1}')
      files+=("$name")
    fi
  done <<< "$list_out"

  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No files found at remote path. Raw listing:\n$list_out"
    return 1
  fi

  log "Found ${#files[@]} files on the share."
  for f in "${files[@]}"; do printf "  - %s\n" "$f"; done

  # If keys were provided via CLI, use them; otherwise prompt selection
  local selected=()
  if [[ -n "$KEYS_CSV" ]]; then
    IFS=',' read -ra selected <<< "$KEYS_CSV"
  else
    if [[ $NON_INTERACTIVE -eq 1 ]]; then
      err "No keys specified and non-interactive mode. Provide --keys."
    fi
    log "Enter comma-separated filenames to copy from share (or 'all' to copy all listed files):"
    read -rp "> " pick
    if [[ "$pick" == "all" ]]; then
      selected=("${files[@]}")
    else
      IFS=',' read -ra tmp <<< "$pick"
      # trim whitespace
      selected=()
      for t in "${tmp[@]}"; do selected+=("$(echo "$t" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"); done
    fi
  fi

  # Ensure ~/.ssh exists
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # Retrieve each selected file with smbclient 'get'
  for keyfile in "${selected[@]}"; do
    # verify file is present in 'files'
    if ! printf "%s\n" "${files[@]}" | grep -Fxq "$keyfile"; then
      warn "Requested key '$keyfile' not found in share; skipping."
      continue
    fi
    log "Fetching $keyfile..."
    # Use smbclient get <remotepath/filename> <localpath>
    local remote_cmd="cd ${remote_path}; get \"${keyfile}\" \"${HOME}/.ssh/${keyfile}\""
    smbclient //"${SMB_SERVER}"/"${SMB_SHARE}" -U "${SMB_USER}%${SMB_PASS}" -c "$remote_cmd" >/dev/null 2>&1 || {
      warn "Failed to fetch $keyfile"
      continue
    }
    # Set permissions: private keys should be 600, public keys 644
    if [[ "$keyfile" =~ \.pub$ ]]; then
      chmod 644 "$HOME/.ssh/$keyfile" || true
    else
      chmod 600 "$HOME/.ssh/$keyfile" || true
    fi
    log "Saved to $HOME/.ssh/$keyfile"
  done

  log "Key fetch complete. Do NOT forget to remove secrets from the share after copying if needed."
}

test_ssh_key_against_github() {
  # Find private keys in ~/.ssh that we might test (non .pub)
  mapfile -t private_keys < <(find "$HOME/.ssh" -maxdepth 1 -type f ! -name "*.pub" -printf "%f\n" 2>/dev/null || true)
  if [[ ${#private_keys[@]} -eq 0 ]]; then
    warn "No private keys found in ~/.ssh to test."
    return 1
  fi

  local key_to_test=""
  if [[ ${#private_keys[@]} -eq 1 ]]; then
    key_to_test="${private_keys[0]}"
    log "Only one private key found: $key_to_test"
  else
    if [[ -n "$KEYS_CSV" && -n "$private_keys" ]]; then
      # try match first key from KEYS_CSV if provided
      IFS=',' read -ra kk <<< "${KEYS_CSV}"
      for k in "${kk[@]}"; do
        if printf "%s\n" "${private_keys[@]}" | grep -Fxq "$k"; then
          key_to_test="$k"
          break
        fi
      done
    fi
    if [[ -z "$key_to_test" ]]; then
      if [[ $NON_INTERACTIVE -eq 1 ]]; then
        key_to_test="${private_keys[0]}"
        log "Non-interactive: selecting first private key: $key_to_test"
      else
        log "Which private key do you want to test against GitHub? Choose a number:"
        local i=1
        for k in "${private_keys[@]}"; do printf "  %2d) %s\n" "$i" "$k"; i=$((i+1)); done
        read -rp "Select (1-${#private_keys[@]}): " sel
        sel=${sel:-1}
        key_to_test="${private_keys[$((sel-1))]}"
      fi
    fi
  fi

  local keypath="$HOME/.ssh/$key_to_test"
  if [[ ! -f "$keypath" ]]; then err "Key $keypath not found"; fi

  log "Testing SSH authentication to GitHub using key $keypath..."
  # GitHub SSH test returns a non-zero code (since it's not an interactive shell) but prints "Hi <user>! ...".
  # Use -o BatchMode=yes to prevent password prompts.
  set +e
  ssh_output=$(ssh -i "$keypath" -o BatchMode=yes -o StrictHostKeyChecking=no -T git@github.com 2>&1)
  ssh_exit=$?
  set -e

  if [[ $ssh_exit -ne 0 && ! "$ssh_output" =~ "successfully authenticated" && ! "$ssh_output" =~ "Hi " ]]; then
    warn "SSH test returned non-success. Output:"
    printf "%s\n" "$ssh_output"
    warn "It may still work for git operations, but SSH reported non-success. You can try adding key to ssh-agent or check GitHub account."
    return 2
  fi

  # Parse username from message "Hi USERNAME! You've successfully authenticated, but GitHub does not provide shell access."
  local gh_user=""
  if [[ "$ssh_output" =~ ^Hi[[:space:]]([a-zA-Z0-9-]+)! ]]; then
    gh_user="${BASH_REMATCH[1]}"
    log "SSH key authenticated as GitHub user: $gh_user"
  else
    warn "Could not parse GitHub username from SSH output. Raw output:\n$ssh_output"
  fi

  # Expose detected username
  GITHUB_SSH_USER="$gh_user"
  return 0
}

list_github_repos_and_clone() {
  local gh_user="$1"
  if [[ -z "$gh_user" ]]; then
    # try git config user name? but the ssh test should have produced username
    warn "No GitHub username detected from SSH. Attempting to find via local git config..."
    gh_user=$(git config --global user.name || true)
    if [[ -z "$gh_user" ]]; then
      warn "Cannot determine GitHub username. Skipping repo listing/clone."
      return 1
    fi
  fi

  log "Listing public repositories for GitHub user: $gh_user"
  # This lists public repos only. Private repos require a token and authenticated API requests.
  repos_json=$(curl -s "https://api.github.com/users/${gh_user}/repos?per_page=200")
  if [[ -z "$repos_json" ]]; then
    warn "GitHub API returned no data. Check network or rate limiting."
    return 1
  fi

  # Parse repo names and clone URLs
  mapfile -t repo_names < <(printf "%s\n" "$repos_json" | grep -oP '"full_name":\s*"\K([^"]+)' | tr -d '\r')
  mapfile -t ssh_urls < <(printf "%s\n" "$repos_json" | grep -oP '"ssh_url":\s*"\K([^"]+)' | tr -d '\r')

  if [[ ${#repo_names[@]} -eq 0 ]]; then
    warn "No public repositories found for $gh_user."
    return 1
  fi

  log "Found ${#repo_names[@]} public repositories for $gh_user:"
  for i in "${!repo_names[@]}"; do
    printf "  %3d) %s\n" $((i+1)) "${repo_names[$i]}"
  done

  local to_clone=()
  if [[ -n "$REPOS_CSV" ]]; then
    IFS=',' read -ra requested <<< "$REPOS_CSV"
    for r in "${requested[@]}"; do
      # allow owner/repo or repo only
      r_trim=$(echo "$r" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      # find index by exact match full_name or by trailing repo name match
      idx=-1
      for i in "${!repo_names[@]}"; do
        if [[ "${repo_names[$i]}" == "$r_trim" || "${repo_names[$i]##*/}" == "$r_trim" ]]; then
          idx="$i"; break
        fi
      done
      if (( idx >= 0 )); then
        to_clone+=("$idx")
      else
        warn "Requested repo '$r_trim' not found in user's public repo list."
      fi
    done
  else
    if [[ $NON_INTERACTIVE -eq 1 ]]; then
      # clone all in non-interactive
      for i in "${!repo_names[@]}"; do to_clone+=("$i"; done
    else
      log "Enter comma-separated numbers of repos to clone (or 'all' to clone all). Example: 1,3,5"
      read -rp "> " choice
      if [[ "$choice" == "all" ]]; then
        for i in "${!repo_names[@]}"; do to_clone+=("$i"); done
      else
        IFS=',' read -ra parts <<< "$choice"
        for p in "${parts[@]}"; do
          p_trim=$(echo "$p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ "$p_trim" =~ ^[0-9]+$ ]]; then
            idx=$((p_trim-1))
            if (( idx >= 0 && idx < ${#repo_names[@]} )); then
              to_clone+=("$idx")
            else
              warn "Index $p_trim out of range; skipping."
            fi
          else
            warn "Invalid selection: $p_trim"
          fi
        done
      fi
    fi
  fi

  # Ensure destination dir
  dest="$HOME/Git"
  mkdir -p "$dest"

  for idx in "${to_clone[@]}"; do
    name="${repo_names[$idx]}"
    url="${ssh_urls[$idx]}"
    target="$dest/${name##*/}"
    if [[ -d "$target/.git" ]]; then
      log "Repository ${name} already cloned at $target. Pulling latest..."
      (cd "$target" && git pull) || warn "git pull failed for $target"
    else
      log "Cloning ${name} into $target..."
      git clone "$url" "$target" || warn "Failed to clone $name"
    fi
  done

  log "Repo clone/pull operations complete."
}

# ----------------------------
# Execute main flow
# ----------------------------
main() {
  log "Starting WSL setup script."

  # Ensure minimal tooling
  ensure_pkg "curl" || true
  ensure_pkg "git" || true
  ensure_pkg "openssh-client" || true
  ensure_pkg "ssh" || true  # some distros
  ensure_pkg "jq" || true   # optional, used nowhere critical but handy

  install_zoxide
  install_homebrew_and_asdf

  # Install terraform & terragrunt via asdf
  install_asdf_latest "terraform"
  install_asdf_latest "terragrunt"

  # Fetch SSH keys from SMB share
  fetch_keys_via_smb || warn "Key fetch step had problems; continuing."

  # Test SSH key against GitHub
  if test_ssh_key_against_github; then
    log "SSH key test succeeded (or reported success)."
    # GITHUB_SSH_USER will be set by the function if detected
    list_github_repos_and_clone "${GITHUB_SSH_USER:-}"
  else
    warn "SSH key test did not confirm authentication to GitHub. You can still clone repos manually."
  fi

  log "All done. Please ensure you add your private key to ssh-agent if you want convenience:"
  printf "  eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/your_key\n"
  log "If you want zoxide available immediately, add its init to your shell rc (install script printed instructions)."
}

main "$@"
