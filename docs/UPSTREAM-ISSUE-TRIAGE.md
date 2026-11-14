# Targeted upstream issue investigations (Android TV 13 / 1.1)

Fork: [NightVibes33/android-tv-ps4](https://github.com/NightVibes33/android-tv-ps4). Original: [odiecay/android-tv-ps4](https://github.com/odiecay/android-tv-ps4).

## [#36: USB storage invisible](https://github.com/odiecay/android-tv-ps4/issues/36)

Android's `vold` requires explicit removable-storage entries in the device fstab ([AOSP device configuration](https://source.android.com/docs/core/storage/config)). The generated `/fstab.mustang` previously declared only cache. This branch adds matching `voldmanaged=` entries for external USB disks already present **before Android boots**.

**Critical safety boundary:** The PS4 internal disk may be USB-attached. This code skips the disk containing partition 27; it never creates a broad USB wildcard, mounts media, writes partitions, or reformats anything. Do not click Format/Adopt if Android offers it.

**Unverified on hardware.** Hotplug after Android starts is not covered; a missing kernel driver or namespace uevent issue may still block detection. Test using a disposable FAT32/exFAT USB stick plugged in before launch. Check `progress.log` for `External USB disk ... registered`, then Android's Storage screen and vold logcat entries.

## [#66: code 60 / GoldHEN timeout](https://github.com/odiecay/android-tv-ps4/issues/66)

The launcher now records the last reached stage, whether it released the display, and elapsed time on timeout. It distinguishes a loader that never finished preparing Linux from a stage-7 handoff that never produced a running Linux system. This **improves diagnostics**; it does not resolve the underlying kernel or handoff failure.

## [#67: no HDMI signal on a display without 1080p](https://github.com/odiecay/android-tv-ps4/issues/67)

Set output to **720p in PS4 Settings before launching**; disable HDR and keep Deep Colour and RGB Range on Automatic. HDCP and Linux HDMI video modes are separate. If no new Linux logs appear, Android's display-mode filter did not cause that early failure. No Baikal HDMI fix is claimed.

## [#95: Baikal Linux freezes after stage 7](https://github.com/odiecay/android-tv-ps4/issues/95)

Stage 7 only means Linux memory and handoff were prepared, not that Linux/Android finished booting. The reported regulatory-domain firmware errors do not by themselves prove why storage or display stalled. Further hardware logs and bisecting are needed; no speculative kernel changes were shipped here.

## Validation and release status

Run `python3 releases/release-1.0/tests/test_usb_fstab.py`. The checked-in prebuilt initramfs and published PKG were **not rebuilt or updated**. To ship these changes, rebuild the initramfs, update its source manifest and pinned hash, build a new PKG, and verify a real PS4 with a noncritical USB stick. Do not treat source-only validation as a working PS4 release.
