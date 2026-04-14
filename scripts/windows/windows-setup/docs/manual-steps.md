# Manual steps

- Review `installers/winget/manual-packages.json` for apps that should stay out of automated install flow.
- Replace placeholder GitLab and TrueNAS examples in `data/*.json` before running against a real machine.
- Export real WinUtil and ShutUp10 profiles into `configs/winutil/` and `configs/shutup10/`.
- Decide whether OBS and Audacious plugin installs should remain manual or move into custom installer scripts.
