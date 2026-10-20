# iOS 26 boot investigation checkpoint

Date: 2026-10-20

## Observed state

PocketDarwin has not booted an iOS home screen. The Windows 11 run uses ChefKiss Inferno under WSL2/TCG and inputs extracted from the iPhone 11 iOS 26.6.2 IPSW. QEMU reports an iOS 26.6.1 kernel, so the version/build pairing still needs an audit.

The first normal-boot probe used a raw APFS System container with no GPT partition table. XNU reached APFS, then waited indefinitely for `disk0s1`. A disposable test copy was wrapped in a GPT with one Apple APFS System partition; the original extracted image remains unchanged and the VM opens the test copy with QEMU snapshot mode.

That let the kernel continue past an early panic caused by unsupported A13 system-register writes. The panic handler identified `MSR S3_2_C15_C2_0`; subsequent runs exposed the contiguous `C3` and `C4` registers. PocketDarwin now overlays per-CPU read/write CPREG storage for `S3_2_C15_C2_0` through `S3_2_C15_C15_0`. The patched QEMU builds successfully. With the register bank present, UART0 shows the display and NVMe drivers starting, APFS mounting, and `launchd` being executed.

The latest boot ends in a kernel panic because PID 1 cannot load `/usr/lib/libSystem.B.dylib`: the System container has no dyld shared cache. The matching cache fragments are present in the separate decrypted Cryptex1 APFS image from the IPSW, but the current Inferno boot path has not installed or mounted that Cryptex. The QEMU screen capture is black. SpringBoard, touch input, and app launch are still unverified.

## USB investigation

The x86_64 companion QEMU with `usb-tcp-remote` and the ARM-side `usb-tcp-host` can establish their TCP connection on localhost port 8030. That validates the transport connection only.

In the earlier recovery/restore run, QEMU reported the DWC3 USB gadget as `attached=false`. The public Inferno DWC3 implementation attaches the gadget when the guest writes `DCTL.RUN_STOP`. Adding a temporary attach at Apple Type-C device realization made Linux repeatedly fail USB descriptor reads with `-71`; that temporary source change was reverted.

The public Inferno discussion below identifies a missing software cable notification from the IOPortTransportState/accessory stack. It also says `force-usb-device` selects the device role but does not itself create the cable-connect event. Both `force-usb-device` and `force-usb2-device` have been tried as boot arguments; the DWC3 gadget remains unattached in the current check.

## Next technical gates

1. Attach Cryptex1 through the correct device-tree/iBoot/restore layout so `launchd` can load its matching dyld cache and `libSystem`.
2. Continue normal boot through userspace and inspect the next panic or service failure without masking it with synthetic system files.
3. Complete the restore/install path, including the required SEP/TSS inputs and USB companion transport, without putting firmware, tickets, keys, or extracted Apple binaries in this repository.
4. Capture the real SpringBoard interface from the Windows host and verify touch input before packaging a user-facing launcher/release or claiming iOS 26 support.

## References

- [Inferno Discussion #312: iOS 16 on Windows 11 and the USB cable notification issue](https://github.com/ChefKissInc/Inferno/discussions/312)
- [Inferno source: DWC3 USB device implementation](https://github.com/ChefKissInc/Inferno/blob/master/hw/usb/hcd-dwc3.c)
- [Inferno source: Apple Type-C USB PHY model](https://github.com/ChefKissInc/Inferno/blob/master/hw/usb/apple_typec.c)

This file records a research checkpoint, not a working emulator claim. The patch files make the A13 register experiment reproducible from the pinned public Inferno source. Firmware inputs and scratch disk images remain outside the repository.
