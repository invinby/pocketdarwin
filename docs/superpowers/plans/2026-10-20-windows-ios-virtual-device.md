# Windows x64 Real iOS Virtual Device Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boot and verify a real iOS 26 graphical environment on the user's Windows 11 x64 Ryzen PC, then prepare a usable public GitHub repository and Windows beta release.

**Architecture:** Use the public ChefKiss Inferno QEMU device model as the guest backend, built and run in Ubuntu under WSL2 with WSLg for its actual emulator display. A Windows PowerShell desktop launcher will preflight WSL2, set up the pinned Linux runtime, prepare user-sourced iOS firmware without distributing it, and start QEMU. Keep all project-specific glue and any legally distributable source changes in this repository; publish the GPL/AGPL-compliant backend source and notices.

**Tech Stack:** QEMU/Inferno (AArch64 TCG), Ubuntu 26.04 under WSL2/WSLg, C# WPF on .NET 10 (self-contained win-x64), Bash for guest-side setup, xUnit for launcher tests, shell integration checks, GitHub Actions for reproducible source/binary packaging.

**Spec:** `docs/superpowers/specs/2026-10-20-windows-ios-virtual-device-design.md`

## Global Constraints

- Target platform is Windows x64 on commodity AMD/Intel hardware, not Apple Silicon.
- The first target host is the user's ROG Strix G513RM (Ryzen 7 6800H).
- A graphical, interactive iPhone interface is the core acceptance target.
- The first GUI milestone is an actual interactive SpringBoard session in a desktop window, with mouse/touch mapping and basic keyboard input.
- Keep all downloaded firmware and derived images out of Git and release artifacts.
- Do not ask users to provide Apple ID credentials to the launcher.
- Never bundle proprietary Apple firmware, signing tickets, or private keys.
- Compatibility claims must be based on observed testing.
- Public release must include source, licenses/notices, setup instructions, compatibility matrix, limitations, and checksums.
- Review the iOS 26 software license and applicable local law before publishing binaries or boot instructions; do not imply Apple endorses or authorizes this use.
- Mark the project unofficial and do not use Inferno branding without permission.

## Review Focus

- **WSL missing, stopped, or using the wrong distro:** the launcher must report the exact repair step and never silently run against a different distro. Covered by Task 1 preflight tests.
- **WSLg/display variables missing:** setup must distinguish a headless environment from an interactive Windows session and show a useful error. Covered by Task 1 and Task 4 tests.
- **Unsupported iOS build/device pairing:** firmware preparation must reject the pairing before altering files and report the model/build it supports. Covered by Task 3 fixture tests.
- **Firmware or APFS preparation interrupted / low disk:** resume or fail without corrupting the only source IPSW; keep scratch and derived images separate. Covered by Task 3 fault tests.
- **Paths with spaces/non-ASCII characters and Windows/WSL path conversion:** the launcher must pass paths without shell interpolation and preserve the user's files. Covered by Task 4 Windows integration tests.

---

## File and Component Map

- `src/launcher/PocketDarwin.Launcher/Services/HostStatusService.cs` — read-only Windows/WSL/WSLg/space preflight for the WPF app.
- `src/launcher/PocketDarwin.Launcher/Services/WslService.cs` — launches the chosen WSL distribution with argument-safe parameters and streams output/errors.
- `src/launcher/PocketDarwin.Launcher/Services/ProcessRunner.cs` — shared async process runner with cancellation, exit code, stdout, and stderr.
- `scripts/linux/install-deps.sh` — installs the pinned WSL Linux build/runtime dependencies with explicit confirmation before privileged package changes.
- `scripts/linux/build-inferno.sh` — checks out the pinned public Inferno revision, applies only reviewed project patches, builds the QEMU AArch64 system emulator with WSLg display support, and writes a build manifest.
- `scripts/linux/prepare-firmware.sh` — downloads or accepts an iOS 26 IPSW, verifies expected device/build and checksums, prepares private scratch images, and never copies firmware into the Git tree.
- `scripts/linux/run-ios.sh` — validates a prepared VM profile and launches the real QEMU iPhone machine with SDL/WSLg display and serial logging.
- `config/backend.lock.json` — exact backend repository, commit, submodule revisions, and license identifiers.
- `config/ios26-device.json` — supported iPhone model/build pairing and required firmware components.
- `src/launcher/PocketDarwin.Launcher/` — self-contained .NET 10 WPF desktop UI for WSL setup status, firmware/device choices, launch/stop, and logs.
- `src/launcher/PocketDarwin.Launcher.Tests/` — xUnit tests for preflight, safe argument passing, state transitions, and WSL errors.
- `tests/linux/` — tests for dependency checks, firmware validation, resume/error behavior, and QEMU launch argument construction.
- `.github/workflows/` — source/license checks, tests, Linux build, Windows launcher build, and unsigned beta packaging.
- `README.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `COMPATIBILITY.md`, `SECURITY.md` — public usage, licensing, support matrix, and limitations.

## Milestones

### Task 1: Windows and WSL host preflight

**Files:**
- Create: `src/launcher/PocketDarwin.Launcher/PocketDarwin.Launcher.csproj`
- Create: `src/launcher/PocketDarwin.Launcher.Tests/PocketDarwin.Launcher.Tests.csproj`
- Create: `src/launcher/PocketDarwin.Launcher/Services/HostInfo.cs`
- Create: `src/launcher/PocketDarwin.Launcher/Services/HostStatusService.cs`
- Create: `src/launcher/PocketDarwin.Launcher.Tests/HostStatusServiceTests.cs`

**Interfaces:**
- Produces `HostInfo` with `WindowsBuild`, `Architecture`, `CpuName`, `RamBytes`, `WslInstalled`, `WslVersion`, `DistroName`, `DistroState`, `WslgAvailable`, `FreeBytes`, and `Errors`.
- `HostStatusService.GetHostInfoAsync(CancellationToken) -> Task<HostInfo>` performs read-only host checks without blocking the WPF UI thread.

- [ ] **Step 1: Write xUnit cases** for Windows x64, WSL2 missing, distro missing, WSL stopped, no WSLg, low disk, and localized command output; assert stable error identifiers and read-only behavior.
- [ ] **Step 2: Run tests and verify failures** with `dotnet test src/launcher/PocketDarwin.Launcher.Tests/PocketDarwin.Launcher.Tests.csproj`.
- [ ] **Step 3: Implement host inspection** using Windows APIs and `wsl.exe --list --verbose`; parse output robustly across localized Windows text by querying the distro directly where possible.
- [ ] **Step 4: Run xUnit tests** and check the WPF preflight screen on the target host reports the actual ROG/Ubuntu/WSL2 state.
- [ ] **Step 5: Commit** the preflight implementation.

### Task 2: Pin and build the public QEMU backend under WSL2

**Files:**
- Create: `config/backend.lock.json`
- Create: `scripts/linux/install-deps.sh`
- Create: `scripts/linux/build-inferno.sh`
- Create: `scripts/linux/verify-backend.sh`
- Create: `tests/linux/test_build_backend.sh`
- Create: `THIRD_PARTY_NOTICES.md`

**Interfaces:**
- `build-inferno.sh --lock <path> --prefix <path>` consumes the pinned source lock and installs a relocatable backend into `<prefix>`.
- `verify-backend.sh --prefix <path>` checks executable version, expected machine type, SDL/WSLg backend, TCG AArch64 support, and compiled patch revision; exits nonzero on mismatch.
- `backend.lock.json` records immutable Git commits, submodule commits, source URLs, and license identifiers.

- [ ] **Step 1: Inspect the chosen public Inferno/Windows source and license files**; select a public commit that can be built without private/unpublished patches and record exact revisions in the lock file.
- [ ] **Step 2: Write shell tests** for malformed lock files, missing tools, failed submodule fetch, build failure, and successful manifest output.
- [ ] **Step 3: Run the shell test suite and verify failures** with `bash tests/linux/test_build_backend.sh`.
- [ ] **Step 4: Implement pinned dependency installation and backend build** for WSL Ubuntu x86_64 using AArch64 TCG and SDL/WSLg; do not enable paths requiring macOS frameworks.
- [ ] **Step 5: Build on this host and run the backend verifier**; capture compiler output, QEMU version, machine list, and license manifest.
- [ ] **Step 6: Commit** the lock, build scripts, tests, and notices.

### Task 3: Safe iOS 26 firmware preparation and private VM profile

**Files:**
- Create: `config/ios26-device.json`
- Create: `scripts/linux/prepare-firmware.sh`
- Create: `scripts/linux/verify-firmware.sh`
- Create: `tests/linux/test_firmware.sh`
- Modify: `.gitignore`

**Interfaces:**
- `verify-firmware.sh --ipsw <path> --profile <path>` emits `device`, `build`, `sha256`, `components`, and `supported` fields; it never prints signing/private key material.
- `prepare-firmware.sh --ipsw-url <url> --profile <path> --state-dir <path>` downloads or resumes into a private state directory and emits only a VM profile path.
- `config/ios26-device.json` pins the iPhone 11/T8030 model and one publicly obtainable iOS 26 build only after source research confirms it can restore.

- [ ] **Step 1: Create IPSW/manifest fixtures** for supported, wrong-device, unsupported-build, truncated-download, and checksum-mismatch cases.
- [ ] **Step 2: Write tests** that assert unsupported inputs fail before extraction, partial downloads resume safely, low-disk space fails before extraction, and firmware paths stay outside the repository.
- [ ] **Step 3: Run `bash tests/linux/test_firmware.sh`** and confirm failures are specific and actionable.
- [ ] **Step 4: Implement firmware inspection and checksums** using a pinned open-source IPSW tool; implement Mac-free APFS handling only after validating the chosen WSL driver and its license.
- [ ] **Step 5: Prepare the user-authorized iOS 26 firmware locally** and verify the device/build pairing without committing any firmware or tickets.
- [ ] **Step 6: Commit** only profile metadata, scripts, tests, and ignore rules.

### Task 4: First real QEMU boot and WSLg graphical display

**Files:**
- Create: `scripts/linux/run-ios.sh`
- Create: `src/launcher/PocketDarwin.Launcher/Services/WslService.cs`
- Create: `src/launcher/PocketDarwin.Launcher.Tests/WslServiceTests.cs`
- Create: `tests/linux/test_run_ios.sh`

**Interfaces:**
- `run-ios.sh --profile <path> --firmware-dir <path> --log <path>` validates all inputs, launches the pinned machine and saves serial/QEMU logs.
- `WslService.StartVmAsync(profilePath, firmwarePath, cancellationToken) -> Task<ProcessResult>` starts only the named WSL distribution and forwards arguments with `ProcessStartInfo.ArgumentList`, without string-built shell commands.

- [ ] **Step 1: Write QEMU command-construction tests** for missing firmware, unsupported profile, WSLg absent, whitespace paths, and normal launch; assert no shell interpolation.
- [ ] **Step 2: Run `bash tests/linux/test_run_ios.sh` and `dotnet test src/launcher/PocketDarwin.Launcher.Tests/PocketDarwin.Launcher.Tests.csproj`** and confirm expected failures.
- [ ] **Step 3: Implement validated QEMU launch** using the pinned T8030 machine, software TCG, WSLg SDL window, keyboard/touch input mapping, and serial log capture.
- [ ] **Step 4: Run a known-good older iOS pairing only as a backend diagnostic**; verify the QEMU model displays the guest's real framebuffer on this Windows desktop.
- [ ] **Step 5: Launch the selected iOS 26 profile**; inspect boot logs and iterate on public, independently reproducible patches until the real SpringBoard is visible and interactive.
- [ ] **Step 6: Capture acceptance evidence**: target machine details, iOS build/device identifier, screenshot of the real SpringBoard window, input-navigation result, and logs with secrets removed.
- [ ] **Step 7: Commit** the launcher scripts and repeatable QEMU profile.

### Task 5: Native app proof and performance characterization

**Files:**
- Create: `docs/APP-COMPATIBILITY.md`
- Create: `tests/acceptance/app-proof.md`
- Modify: `config/ios26-device.json` if verified compatibility requires a different supported iPhone/iOS pairing.

**Interfaces:**
- `APP-COMPATIBILITY.md` records app name, source/license, signing/provisioning path, tested guest build, result, and known limitation.

- [ ] **Step 1: Select a legally obtainable test app** whose source and signing path do not require the user to submit Apple ID credentials to the project.
- [ ] **Step 2: Document the expected install and launch result** before trying it.
- [ ] **Step 3: Install and launch it inside the verified iOS 26 guest**; record crash/log evidence and repeat after VM restart.
- [ ] **Step 4: Measure cold boot, SpringBoard frame rate, CPU/RAM, and storage growth** on the target ROG; record constraints without changing the iOS 26 goal.
- [ ] **Step 5: Commit** the evidence template and observed compatibility report.

### Task 6: User-facing desktop launcher and one-download setup

**Files:**
- Create: `src/launcher/PocketDarwin.Launcher/PocketDarwin.Launcher.csproj`
- Create: `src/launcher/PocketDarwin.Launcher/App.xaml`
- Create: `src/launcher/PocketDarwin.Launcher/MainWindow.xaml`
- Create: `src/launcher/PocketDarwin.Launcher/ViewModels/MainViewModel.cs`
- Create: `src/launcher/PocketDarwin.Launcher/Services/ProcessRunner.cs`
- Create: `src/launcher/PocketDarwin.Launcher.Tests/MainViewModelTests.cs`
- Modify: `src/launcher/PocketDarwin.Launcher/Services/WslService.cs` only through its defined interface.

**Interfaces:**
- Launcher states: `CheckingHost`, `NeedsWsl`, `NeedsUbuntu`, `NeedsBackend`, `NeedsFirmware`, `Ready`, `Booting`, `Running`, `Failed`.
- Launcher actions: `CheckHostAsync()`, `InstallWslAsync()`, `InstallDistroAsync()`, `PrepareBackendAsync()`, `PrepareFirmwareAsync()`, `StartVmAsync()`, `StopVmAsync()`, `OpenLogs()`.
- Every setup operation reports progress, cancellation, and a stable error code; never blocks the UI thread.

- [ ] **Step 1: Create a self-contained `net10.0-windows` WPF launcher** after the CLI boot works; target `win-x64` and bundle the runtime so users do not need to install .NET.
- [ ] **Step 2: Write view-model tests** for every state transition, cancellation, and failure identifier.
- [ ] **Step 3: Implement a single-window desktop flow** with explicit WSL setup, firmware progress, Start/Stop, and logs; ask before privileged WSL installation and never reboot automatically; no web-based fake phone UI.
- [ ] **Step 4: Run UI smoke tests** on the target Windows machine and confirm the guest remains a separate genuine QEMU display.
- [ ] **Step 5: Publish a self-contained Windows x64 launcher artifact** and verify clean start on a fresh Windows profile with no preinstalled QEMU or .NET runtime.
- [ ] **Step 6: Commit** the launcher and packaging metadata.

### Task 7: Public source compliance and GitHub beta release

**Files:**
- Create: `README.md`, `LICENSE`, `COMPATIBILITY.md`, `SECURITY.md`.
- Modify: `THIRD_PARTY_NOTICES.md` with the complete source and license audit.
- Create: `.github/workflows/ci.yml`, `.github/workflows/release.yml`.
- Create: `scripts/release/check-artifact.sh`.

**Interfaces:**
- CI builds the Linux QEMU backend and Windows launcher from pinned commits and runs all unit/integration checks that do not require Apple firmware.
- Release packaging includes source, notices, binary checksums, setup steps, firmware download explanation, limits, and a compatibility table.

- [ ] **Step 1: Complete source and license audit** for every vendored/submodule dependency and choose a compatible project license.
- [ ] **Step 2: Write artifact audit tests** that fail if IPSW, DMG, SEP, signing ticket, private key, local VM disk, or WSL user data is included in Git or release archives.
- [ ] **Step 3: Add CI** for Windows script tests, Linux shell tests, source build, and secret/firmware artifact scans.
- [ ] **Step 4: Build the exact release archives in CI** and locally inspect manifests, licenses, checksums, and file list.
- [ ] **Step 5: Run the release candidate on the target ROG PC** and reconfirm the iOS 26 SpringBoard and app-proof results from a clean VM state.
- [ ] **Step 6: Complete legal review of the iOS 26 use case** before publishing binaries or recommending users download/boot firmware on non-Apple hardware.
- [ ] **Step 7: Create the public GitHub repository and publish the reviewed beta release** only after all prior release checks pass.

## Acceptance Audit

- Evidence must show the actual iOS 26 guest (device/build identified), interactive SpringBoard, mouse/touch navigation, and at least one native app launch on the user's Windows 11 x64 Ryzen machine.
- A QEMU version string, shell prompt, boot log, simulated screen, or CI build alone does not satisfy graphical iOS acceptance.
- Public repository and release must build from pinned open-source source, exclude Apple firmware/tickets/keys, satisfy included software licenses, and pass the target ROG clean-start procedure.
