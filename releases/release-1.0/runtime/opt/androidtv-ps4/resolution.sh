# Android's display must match modes the TV actually advertises. The old
# unconditional 1920x1080 override made 720p-only screens unusable (#67).
# The kernel/HDMI handoff happens earlier; this affects framework sizing only.
atv_choose_resolution() {
 sysroot=$1
 fallback=
 for connector in "$sysroot"/class/drm/card*-HDMI-A-*; do
  [ -r "$connector/status" ] && [ -r "$connector/modes" ] || continue
  [ "$(cat "$connector/status")" = connected ] || continue
  if grep -qx '1920x1080' "$connector/modes"; then
   printf '1920x1080\n'; return 0
  fi
  if grep -qx '1280x720' "$connector/modes"; then
   fallback=1280x720
  fi
 done
 [ -n "$fallback" ] && { printf '%s\n' "$fallback"; return 0; }
 return 1
}
# WindowManager is unavailable during init.sh eglsetup and post-fs.
if [ "$(getprop sys.boot_completed)" = 1 ]; then
 mode=$(atv_choose_resolution /sys || true)
 case "$mode" in
  1920x1080) wm size 1920x1080; wm density 320 ;;
  1280x720) wm size 1280x720; wm density 240 ;;
  *) wm size reset; wm density reset ;;
 esac
fi
