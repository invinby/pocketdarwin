# iOS 26 boot investigation checkpoint

Date: 2026-10-20

## Observed state

PocketDarwin has not booted an iOS home screen. The current Windows 11 run uses ChefKiss Inferno under WSL2/TCG and the iPhone 11 iOS 26.6.2 firmware inputs. The QEMU startup output identifies the loaded kernel as iOS 26.6.1, so the version/build pairing needs another audit.

The ARM guest is currently booted into recovery/RestoreOS with an Erase Restore ramdisk. Its 16 GB root target is not a completed installed iOS system. The captured guest display is still the Inferno splash screen, and the configured UART log is empty. No iOS GUI, touch input, or app launch has been verified.

## USB investigation

The x86_64 companion QEMU with `usb-tcp-remote` and the ARM-side `usb-tcp-host` can establish their TCP connection on localhost port 8030. That validates the transport connection only.

In the current run, QEMU reports the DWC3 USB gadget as `attached=false`. The public Inferno DWC3 implementation attaches the gadget when the guest writes `DCTL.RUN_STOP`. Adding a temporary attach at Apple Type-C device realization made Linux repeatedly fail USB descriptor reads with `-71`; that temporary source change was reverted.

The public Inferno discussion below identifies a missing software cable notification from the IOPortTransportState/accessory stack. It also says `force-usb-device` selects the device role but does not itself create the cable-connect event. Both `force-usb-device` and `force-usb2-device` have been tried as boot arguments; the DWC3 gadget remains unattached in the current check.

## Next technical gates

1. Reproduce the iOS cable-connect notification in the emulator's Type-C/accessory model, then verify that the guest brings DWC3 into `RUN_STOP` and the companion can enumerate it.
2. Complete an authentic restore/install path for the guest system volume, including the required SEP/TSS inputs, without putting firmware, tickets, keys, or extracted Apple binaries in this repository.
3. Boot the installed system in normal mode and capture the actual iOS graphical interface from the Windows host.
4. Only then package a user-facing launcher/release and claim iOS 26 support.

## References

- [Inferno Discussion #312: iOS 16 on Windows 11 and the USB cable notification issue](https://github.com/ChefKissInc/Inferno/discussions/312)
- [Inferno source: DWC3 USB device implementation](https://github.com/ChefKissInc/Inferno/blob/master/hw/usb/hcd-dwc3.c)
- [Inferno source: Apple Type-C USB PHY model](https://github.com/ChefKissInc/Inferno/blob/master/hw/usb/apple_typec.c)

This file records a research checkpoint, not a working emulator claim.
