# homelab-public

Small bootstrap and maintenance scripts for my homelab.

## Structure

- repo root: clone bootstrap helpers
- `scripts/nixos/`: NixOS setup
- `scripts/proxmox/`: Proxmox post-install and cluster recovery
- `scripts/windows/`: Windows setup
- `scripts/wsl/`: WSL setup

## Pull The Repo

Linux/macOS/WSL:

```bash
curl -fsSL https://raw.githubusercontent.com/gallbotond/homelab-public/main/clone-homelab-public.sh | bash
```

PowerShell:

```powershell
irm https://raw.githubusercontent.com/gallbotond/homelab-public/main/clone-homelab-public.ps1 | iex
```

Both commands install `git` if needed and clone the repo into `~/Git/homelab-public`.
