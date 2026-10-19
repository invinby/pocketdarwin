# PocketDarwin

**Early research build. This project does not boot iOS yet.**

PocketDarwin is a Windows 11 x64 launcher and build workflow for investigating a real iPhone guest in QEMU under WSL2. The current checkpoint contains a Windows host-status window and a pinned build script for the public ChefKiss Inferno source. No iOS firmware, restore image, signing ticket, or private key is included.

## Current status

- The WPF launcher checks Windows, WSL2, Ubuntu, and WSLg.
- The backend lock pins ChefKiss Inferno to commit `cc4302a99167abec69b714cfd00c38caece7e7de`.
- The Linux build script and lock-validation checks are experimental.
- iOS 26 restore, SpringBoard graphics, touch input, and native app launch have **not** been verified by this project.
- Do not treat this repository as a working iOS emulator or release build.

## Build the backend in WSL2 Ubuntu

Install the build dependencies in Ubuntu/WSL2, then run:

```bash
bash tests/linux/test_build_backend.sh
NINJA_JOBS=4 bash scripts/linux/build-inferno.sh \
  --lock config/backend.lock.json \
  --prefix "$HOME/.local/share/PocketDarwin/backend"
```

The backend is built from its pinned upstream source. Apple firmware is not downloaded or packaged by this build step.

## Windows launcher

Build and run the current host-check window from PowerShell:

```powershell
dotnet run --project src/launcher/PocketDarwin.Launcher/PocketDarwin.Launcher.csproj
```

## Upstream and limitations

PocketDarwin uses the public [ChefKiss Inferno](https://github.com/ChefKissInc/Inferno) QEMU fork as its research backend. Inferno's own compatibility notes and issues are the source of truth for supported device and iOS pairings. iOS 26 compatibility remains experimental upstream; PocketDarwin will only claim a version after a repeatable boot is observed on Windows/WSL2.

## License

PocketDarwin's original launcher and integration scripts are MIT licensed. See `LICENSE` and `THIRD_PARTY_NOTICES.md`. The separately fetched Inferno/QEMU source retains its own licenses and notices.
