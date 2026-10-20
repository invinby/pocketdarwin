# PocketDarwin

**Early research build. The iOS 26 kernel reaches `launchd`, then panics before SpringBoard.**

PocketDarwin is a Windows 11 x64 launcher and build workflow for investigating a real iPhone guest in QEMU under WSL2. The current checkpoint contains a Windows host-status window and a pinned build script for the public ChefKiss Inferno source. No iOS firmware, restore image, signing ticket, or private key is included.

## Current status

- The WPF launcher checks Windows, WSL2, Ubuntu, and WSLg.
- The backend lock pins public Inferno commit `cc4302a99167abec69b714cfd00c38caece7e7de`.
- PocketDarwin carries a small A13 system-register patch series for registers that the iOS 26 kernel writes during early boot but the upstream model did not define.
- With that patch, the iOS kernel initializes the T8030 display and NVMe drivers, mounts the System APFS volume, and starts `launchd` under WSL2/TCG.
- The guest then panics because the System volume cannot find `/usr/lib/libSystem.B.dylib` in a dyld shared cache. The matching cache is in the separate iOS 26 Cryptex1 image and is not yet mounted by the guest boot flow.
- The captured display is black; SpringBoard, touch input, and app launch are **not** verified. This repository is still a research prototype, not a working iOS emulator release.
- Do not treat this repository as a working iOS emulator or release build.

## iOS 26 firmware research input

To fetch the iPhone 11 iOS 26.6.2 IPSW from Apple's update CDN into a private folder outside this repository:

```bash
python3 scripts/linux/download_ipsw.py \
  --device iPhone12,1 \
  --version 26.6.2 \
  --output "$HOME/.local/share/PocketDarwin/firmware/iPhone12,1_26.6.2.ipsw"
```

The downloader rejects non-Apple firmware hosts and checks the completed file against the catalog SHA-256. The catalog currently lists this iOS 26 build as unsigned for iPhone 11. A downloaded IPSW is only a research input; it does not provide a restore ticket or mean the guest can boot. The extracted System image and Cryptex1 remain in a private folder outside this repository.

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

PocketDarwin uses the public [ChefKiss Inferno](https://github.com/ChefKissInc/Inferno) QEMU fork as its research backend. Inferno's own compatibility notes and issues are the source of truth for supported device and iOS pairings. The current checkpoint proves kernel-to-launchd progress only. PocketDarwin will only claim a working iOS version after the SpringBoard interface is repeatedly observed on Windows/WSL2.

## License

PocketDarwin's original launcher and integration scripts are MIT licensed. See `LICENSE` and `THIRD_PARTY_NOTICES.md`. The separately fetched Inferno/QEMU source retains its own licenses and notices.
