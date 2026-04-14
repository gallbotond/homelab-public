# Recovery notes

- Use `-DryRun` before running a new manifest on a fresh machine.
- Keep exported app configs under `configs/` so a rebuilt machine can be rehydrated from versioned files.
- Prefer adding new behavior through manifests first and custom scripts second.
