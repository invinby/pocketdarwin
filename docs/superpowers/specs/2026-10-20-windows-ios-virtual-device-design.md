# Windows x64 Real iOS Virtual Device — Design

Date: 2026-10-20
Status: Draft for user review

## Goal

Build an open-source project that can boot a real iOS 26 system on a conventional Windows 11 x64 PC with an AMD Ryzen CPU, display and interact with its graphical interface, and provide a path to running iOS applications. The first target host is the user's ROG Strix G513RM (Ryzen 7 6800H). The product must not fake the OS with a web mockup or replace iOS with an independently implemented shell.

The public GitHub repository and release should let technically capable users obtain the launcher and emulator without manually assembling a research environment. Apple firmware must be fetched from Apple-controlled endpoints during setup; copyrighted firmware is not to be bundled into the repository or release.

## User goals and constraints

- Real iOS, initially version 26, running in a virtual device.
- A graphical, interactive iPhone interface is the core acceptance target.
- Applications must eventually be installable and runnable; compatibility claims must be based on observed testing.
- Target platform is Windows x64 on commodity AMD/Intel hardware, not Apple Silicon.
- Package the project as a usable public GitHub repository and release.
- Choose implementation details autonomously and continue toward a verified boot on the target machine.

## Approaches considered

1. **Port vphone-cli directly.** Rejected as the primary path. It depends on Apple's Virtualization.framework and physical Apple Silicon hardware, so changing its front end cannot make it run on Windows x64.
2. **Extend the QEMU-based Inferno iPhone machine.** Recommended. Inferno already models Apple ARM iPhone hardware and has a graphical display/input path. Publicly documented, reproducible support is still old iOS (iPhone 11 / iOS 14.0 beta 5); newer versions are experimental. Its iOS 26 compatibility work is active and not yet a stable user release. An unofficial front end publishes Windows/WSL2 bundles, but its own release notes say those builds have not been tested on real Windows. Reuse only published source, preserve GPL/AGPL notices and obligations, and build a separate user-friendly Windows setup/release around the QEMU backend. This avoids reimplementing the whole Apple device model while keeping the requested Windows x64 target.
3. **Use darwin-vm as the primary base.** Rejected for the graphical product. It demonstrates recent iOS kernels booting under QEMU across host architectures, but its stated endpoint is a root shell and it requires a Mac for firmware preparation. Keep it as a reference for the modern boot chain, not the primary GUI emulator.

## Proposed architecture

### 1. Windows launcher and setup tool

A small Windows x64 launcher guides the user through prerequisites, downloads/validates permitted firmware inputs, creates a VM profile, launches QEMU, and surfaces logs and errors. The launcher must not contain Apple firmware. Initial prototype may use CLI scripts; a polished GUI is deferred until the boot path is demonstrated.

### 2. QEMU device backend

Start from the public ChefKiss Inferno QEMU fork and its iPhone 11 / T8030 machine model, then isolate Windows-specific build, firmware preparation, and user-interface work in this project. First reproduce a published guest configuration. Next bring the current iOS 26 support work to a repeatable state using only public source and lawful firmware inputs. Then verify the display and touch/input path through SpringBoard. Do not copy code from unreleased/private projects or claim parity before observable evidence.

### 3. Firmware preparation

Fetch supported iOS 26 restore firmware from Apple servers at setup time. Record version, device identifier, source URL, and checksums. Apply only documented transformations needed by the emulation path. Keep all downloaded firmware and derived images out of Git and release artifacts. Fail with a clear message when a firmware/device pairing is unsupported.

### 4. User interaction

The first GUI milestone is an actual interactive SpringBoard session in a desktop window, with mouse/touch mapping and basic keyboard input. The first application milestone is launching a known compatible native iOS app in the VM. App Store, Apple ID, cellular, camera, secure enclave fidelity, and broad third-party app compatibility are not promised until separately verified.

### 5. Packaging and release

After the target machine has passed acceptance, publish source, Windows x64 release artifacts, setup instructions, compatibility matrix, limitations, licenses/notices, and checksums. CI builds are useful but do not count as proof of runtime on the user's AMD PC.

## Milestones and acceptance checks

### M0 — Host and source baseline

- Current host: Windows 11 Pro x64 build 26200, AMD Ryzen 7 6800H (8 cores / 16 threads), 16 GB installed RAM (15.3 GB visible), NVIDIA GeForce RTX 3060 Laptop GPU with 6 GB VRAM, hardware virtualization enabled, Ubuntu 26.04 under WSL2 installed, approximately 217 GB free on C:. No `qemu-system-aarch64` executable is currently on Windows PATH.
- Primary codebase candidate: ChefKiss Inferno, a QEMU derivative with an Apple iPhone machine model and active iOS 26 compatibility work. Its public README reports iPhone 11/iOS 14.0 beta 5 as tested; iOS 18.5 is experimental and iOS 26 is not listed as a supported release pairing. Its QEMU changes are GPLv3 and its project code AGPLv3; publication requires a compatible license and source/notices.
- Reference candidate: jprx/darwin-vm proves newer Darwin boot research can run on non-ARM QEMU hosts, but currently targets a root shell and its file preparation requires macOS.
- Confirm the exact public Inferno revision, Windows/WSL2 build path, and supported iPhone 11/iOS 26 pairing before implementation.
- Confirm how supported iOS 26 firmware is obtained and prepared without redistribution.

### M1 — Reproducible build and boot research prototype

- Build the selected QEMU backend for Windows x64 or provide a documented Linux/WSL2 host path if native Windows is not initially feasible.
- From a clean workspace, prepare a supported real iOS 26 firmware image and boot it to the earliest reliable guest milestone.
- Preserve logs and commands so the result is repeatable.

### M2 — Graphical iOS

- Reach the genuine iOS SpringBoard, not a mock UI.
- Render it in a window and verify mouse/touch input can navigate the interface.
- Record performance, failures, and device/version pairing.

### M3 — Application proof

- Install or otherwise provision a legally obtained compatible native iOS app using a documented flow.
- Launch it and record what works and what does not.
- Only advertise app support actually verified on the VM.

### M4 — Public beta release

- Create a public GitHub repository with source, build scripts, documentation, license notices, and issue templates.
- Produce a Windows x64 beta release only after M2 passes on the target ROG PC.
- Mark it experimental if M3 or hardware compatibility remains limited.

## Quality, safety, and legal boundaries

- Never bundle proprietary Apple firmware, signing tickets, or private keys.
- Do not ask users to provide Apple ID credentials to the launcher.
- Use checksums and explicit source/version reporting for firmware inputs.
- Review the licenses of any QEMU fork, patches, scripts, and third-party components before publication; preserve required notices and source obligations.
- Before publishing binaries or user instructions that download and boot iOS on non-Apple PC hardware, review the current iOS 26 license and applicable local law with qualified counsel. Apple's license text grants use on a single Apple-branded device and restricts modification/reverse engineering, subject to stated exceptions; downloading firmware from Apple does not by itself resolve whether this project or a user's use is permitted. Do not represent an unofficial disclaimer as permission from Apple.
- Avoid misleading claims such as “everything works” until features have been individually verified.
- Keep the project independent of Apple and clearly label it as unofficial.

## Research evidence captured 2026-10-20

- Inferno issue [#268: iOS 16-27 support](https://github.com/ChefKissInc/Inferno/issues/268) remains in progress. The maintainer reported on 2026-10-11 that prerequisites were complete but some work was not pushed; iOS 27 still failed during restore.
- Inferno discussion [#312](https://github.com/ChefKissInc/Inferno/discussions/312) includes an independent Windows 11 attempt and reports the maintainer had iOS 26 working privately but did not consider the emulator/tools ready for release. Treat this as feasibility evidence, not a reproducible public build.
- The current [iPhone-VM v0.5.0 release](https://github.com/UltraFEmotes/iPhone-VM/releases/tag/v0.5.0-experimental) includes a refreshed Windows/WSL2 frontend and Linux/APFS improvements, but still calls Windows runtime coverage experimental and says guest Metal/AGX acceleration is unavailable. Its install guide's tested pairing remains iPhone 11 / iOS 14.0 beta 5; iOS 26 is not a verified turnkey profile.
- The public [Inferno iOS 16–27 tracking issue](https://github.com/ChefKissInc/Inferno/issues/268) was still open when checked on 2026-10-20. Its maintainer said some prerequisites were complete but not yet pushed; iOS 27 restore still failed at `install_splat`. This supports trying the exact public master commit, but it is not evidence that a reproducible iOS 26 build is ready.
- Inferno's Windows Q&A [#212](https://github.com/ChefKissInc/Inferno/discussions/212) says firmware filesystem patching needs macOS or an experimental APFS driver on Linux/WSL2. A Mac-free WSL setup is therefore a required early validation item, not an assumed feature.
- The current WSL2 instance has 16 logical CPUs and about 7.4 GiB available to Linux at idle. The Windows host has 16 GB RAM total, so memory allocation and software-emulation speed need measurement before defining other users' minimum specs.
- Apple's current [iOS 26 software license](https://www.apple.com/legal/sla/docs/iOS26_iPadOS26.pdf) describes a limited license to use Apple software on one Apple-branded device and restricts modification/reverse engineering, subject to its terms and legal exceptions. This is a release diligence item, not a legal determination about a particular user's use or jurisdiction.
- Inferno identifies itself as a QEMU derivative and specifies GPLv3 for the overall project and AGPLv3 for its own code. Its branding has separate restrictions; any downstream project must review them before choosing a name or publishing binaries.
- [darwin-vm](https://github.com/jprx/darwin-vm) supports modern iPhone SoC boot research and non-ARM hosts, but advertises a root shell rather than SpringBoard.
- QEMU's [TCG documentation](https://www.qemu.org/docs/master/about/emulation.html) confirms cross-architecture system emulation is supported in principle; that does not establish that the iPhone devices, iOS 26 boot chain, or GUI work on Windows.

## Main technical risks

- QEMU research may not include sufficient models for the iOS 26 boot chain, graphics, touch, SEP, or device services.
- The existing boot path may depend on a Mac for firmware preparation or Apple-only tools.
- Windows x64 may lack required host capabilities or the backend may need WSL2, reducing ease of use.
- Even a graphical boot may not support arbitrary apps because of signing, hardware services, or OS assumptions.
- Software emulation may be too slow for normal use.
- Reusing QEMU research code may impose source publication and license compatibility obligations.

## Decision rule

Continue expanding the backend only when each milestone has a repeatable, observable result. If a milestone fails, investigate the concrete missing component and keep the repo honest; do not substitute a mockup or relabel a shell boot as a usable iPhone. The goal remains the graphical iOS target, with the smallest reliable path chosen at each step.
