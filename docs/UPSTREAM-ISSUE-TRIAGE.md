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

## [#85](https://github.com/odiecay/android-tv-ps4/issues/85), [#88](https://github.com/odiecay/android-tv-ps4/issues/88): firmware 14.00

PS4 Linux Loader v25.2 added 14.00 offsets. This branch ports its 14.00 `magic.h` kexec offsets, builds an additional firmware-specific loader, and supplies the 14.00 `fw_offsets_t` record to the existing embedded AIO helper. It **does not reuse 13.52 offsets** for 14.00. The embedded `linux.elf` remains pinned, so this is an ABI-level compatibility experiment with a separate 14.00 table, not a new external image. Source reference: `SENeoV/ps4-linux-loader-ps4linux` commit `581438f804f5fc288cf310abad585f93260e4f1d`, derived from ps4-linux-loader. The 14.00 helper structure has a host ABI test; its kernel addresses and startup remain untested on an actual firmware 14.00 console.

14.02 stays unsupported here. A newer loader tag advertising 14.02 is **not** proof it shares 14.00 kernel symbols.

## [#67](https://github.com/odiecay/android-tv-ps4/issues/67): display size policy

The old Android framework script always forced `1920x1080`. It now reads connected HDMI modes from sysfs: 1080p if explicitly listed, otherwise 720p if listed, otherwise resets size/density and leaves the display native. This cannot fix HDMI outages occurring *before* Android starts.

## More safeguards

USB enumeration is now fail-closed if the PS4's internal partition 27 cannot be identified. This prevents an ambiguous USB bus from being exported to Android's storage manager.

The CI workflow checks both policies and builds the isolated 14.00 kexec object. Its passing status only establishes host compatibility, not PS4 hardware behavior.

## [#51](https://github.com/odiecay/android-tv-ps4/issues/51) and [#52](https://github.com/odiecay/android-tv-ps4/issues/52): PS4 Pro restart stalls

The host supervisor now waits up to 15 seconds for the bootstrap log collector and refuses reboot if it is still writing. An optional Gboard APK bind mount is released before app mounts, overlay, SquashFS and UFS; missing Gboard is harmless. These changes are based on upstream Android 16 shutdown cleanup and have host regression tests. They reduce unsafe teardown conditions but do **not** prove a PS4 Pro can recover its HDMI or reset sequence.

## Reproducible runtime additions

`repack-runtime.py` now recovers already-shipped hardware additions from the verified original initramfs and its companion MT7668 firmware bundle, with per-file SHA256 checks against `runtime-additions.json`. The optional `--additions` directory can still supply matching inputs. Missing or unexpected inputs fail rather than silently changing device firmware.
