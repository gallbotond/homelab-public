# Windows setup

This folder contains a data-driven PowerShell scaffold for bootstrapping a Windows machine.

## Entry points

- `bootstrap.ps1`: thin wrapper that warns if the shell is not elevated and then calls `main.ps1`
- `main.ps1`: orchestrates setup steps, selectors, and shared manifests

## Example usage

```powershell
pwsh -File .\scripts\windows\windows-setup\main.ps1 -ListSteps
pwsh -File .\scripts\windows\windows-setup\main.ps1 -DryRun -NonInteractive
pwsh -File .\scripts\windows\windows-setup\main.ps1 -Step winget,creds -DryRun
```

## Local overrides

- Put machine-specific values in `data/*.local.json`
- Keep runtime secrets out of git under `secrets/runtime/`
- Replace template configs in `configs/` with your real exports over time
