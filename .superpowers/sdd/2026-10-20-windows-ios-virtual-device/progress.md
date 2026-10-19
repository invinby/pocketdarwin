# SDD ledger — plan: docs/superpowers/plans/2026-10-20-windows-ios-virtual-device.md

Pre-flight: Task 1 produces HostInfo and HostStatusService; Tasks 4/6 consume them through WslService and view-model state — interface review pending implementation.
Pre-flight: Task 2 produces backend.lock.json and build-inferno.sh; Task 4 consumes the built machine and manifest — pin format must be shared.
Pre-flight: Task 3 produces private VM profile; Task 4 consumes profile and firmware paths — no firmware goes in repo.
Pre-flight: Task 6 consumes Tasks 1/4 HostInfo/WslService and Task 2/3 scripts; currently aligned at interface level.
Task 1: Ruling: WPF project file is created in Task 1 and modified in Task 6, not recreated — avoids duplicate path ownership.
Task 1: Ruling: User authorized pursuing implementation in this main checkout by requesting autonomous end-to-end execution — no separate branch needed.
Task 1: Ruling: Goal and publication must be evidence-led; if the public backend cannot boot iOS 26 GUI, repository will state the concrete limit rather than claim launch.
Task 1: partial implementation committed (host preflight + 2 xUnit cases; suite 2/2 pass). Actual Ubuntu/WSLg confirmed live with wayland-0 and :0; remaining planned distro/localization/low-disk cases and visible WPF screen are not complete.
