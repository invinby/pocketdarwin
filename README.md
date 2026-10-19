# PocketDarwin

**Early research build. The QEMU backend builds on this host; this project does not boot iOS yet.**

PocketDarwin is a Windows 11 x64 launcher and build workflow for investigating a real iPhone guest in QEMU under WSL2. The current checkpoint contains a Windows host-status window and a pinned build script for the public ChefKiss Inferno source. No iOS firmware, restore image, signing ticket, or private key is included.

## Current status

- The WPF launcher checks Windows, WSL2, Ubuntu, and WSLg.
- The backend lock pins the public Inferno `dev` branch snapshot to commit `6541861f4d033a0de327b5ccc5180ebac20bf461`.
- That pinned development backend compiled successfully in Ubuntu 26.04 under WSL2 on the first target Windows PC.
- The resulting binary reports the `t8030` (iPhone 11) machine and includes the SDL display backend. This confirms the emulator backend build and host display support only.
- iOS 26 restore, SpringBoard graphics, touch input, and native app launch have **not** been verified by this project.
- Do not treat this repository as a working iOS emulator or release build.

## iOS 26 firmware research input

To fetch the iPhone 11 iOS 26.6.2 IPSW from Apple's update CDN into a private folder outside this repository:

```bash
python3 scripts/linux/download_ipsw.py \
  --device iPhone12,1 \
  --version 26.6.2 \
  --output "$HOME/.local/share/PocketDarwin/firmware/iPhone12,1_26.6.2.ipsw"
```

The downloader rejects non-Apple firmware hosts and checks the completed file against the catalog SHA-256. The catalog currently lists this iOS 26 build as unsigned for iPhone 11. A downloaded IPSW is only a research input; it does not provide a restore ticket or mean the guest can boot.

After the download finishes, inspect the iPhone 11 restore identities and firmware paths without unpacking the entire archive:

```bash
python3 scripts/linux/inspect_ipsw.py \
  "$HOME/.local/share/PocketDarwin/firmware/iPhone12,1_26.6.2.ipsw"
```

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
