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
2. **Extend QEMU-based Darwin boot research.** Recommended. Existing work demonstrates selected iOS versions booting in QEMU to a root shell. Reuse its boot-chain and firmware preparation work where licensing permits, then investigate the device models and display/input/services needed for graphical iOS. This has the highest uncertainty but directly targets the requested host and outcome.
3. **Ship the shell-only QEMU setup as the end product.** Rejected as the final product because it does not satisfy graphical iOS or app use. It may be an internal milestone and a useful early diagnostic artifact.

## Proposed architecture

### 1. Windows launcher and setup tool

A small Windows x64 launcher guides the user through prerequisites, downloads/validates permitted firmware inputs, creates a VM profile, launches QEMU, and surfaces logs and errors. The launcher must not contain Apple firmware. Initial prototype may use CLI scripts; a polished GUI is deferred until the boot path is demonstrated.

### 2. QEMU device backend

Use a controlled QEMU fork or an upstreamable QEMU extension. Keep the emulated iPhone machine configuration and devices behind a documented profile. The work is incremental: start with the known iOS boot path, then add the minimum hardware/services needed to reach the graphical interface. The exact display, input, storage, networking, audio, and secure-processor model is an open research risk; do not claim parity before evidence.

### 3. Firmware preparation

Fetch supported iOS 26 restore firmware from Apple servers at setup time. Record version, device identifier, source URL, and checksums. Apply only documented transformations needed by the emulation path. Keep all downloaded firmware and derived images out of Git and release artifacts. Fail with a clear message when a firmware/device pairing is unsupported.

### 4. User interaction

The first GUI milestone is an actual interactive SpringBoard session in a desktop window, with mouse/touch mapping and basic keyboard input. The first application milestone is launching a known compatible native iOS app in the VM. App Store, Apple ID, cellular, camera, secure enclave fidelity, and broad third-party app compatibility are not promised until separately verified.

### 5. Packaging and release

After the target machine has passed acceptance, publish source, Windows x64 release artifacts, setup instructions, compatibility matrix, limitations, licenses/notices, and checksums. CI builds are useful but do not count as proof of runtime on the user's AMD PC.

## Milestones and acceptance checks

### M0 — Host and source baseline

- Capture exact Windows build, CPU, memory, GPU, free disk, virtualization state, and available QEMU/WSL environment.
- Select a reusable upstream base after source/license review.
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
- Avoid misleading claims such as “everything works” until features have been individually verified.
- Keep the project independent of Apple and clearly label it as unofficial.

## Main technical risks

- QEMU research may not include sufficient models for the iOS 26 boot chain, graphics, touch, SEP, or device services.
- The existing boot path may depend on a Mac for firmware preparation or Apple-only tools.
- Windows x64 may lack required host capabilities or the backend may need WSL2, reducing ease of use.
- Even a graphical boot may not support arbitrary apps because of signing, hardware services, or OS assumptions.
- Software emulation may be too slow for normal use.
- Reusing QEMU research code may impose source publication and license compatibility obligations.

## Decision rule

Continue expanding the backend only when each milestone has a repeatable, observable result. If a milestone fails, investigate the concrete missing component and keep the repo honest; do not substitute a mockup or relabel a shell boot as a usable iPhone. The goal remains the graphical iOS target, with the smallest reliable path chosen at each step.
