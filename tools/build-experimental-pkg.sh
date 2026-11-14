#!/usr/bin/env bash
# Experimental source-to-PKG build, with fully verified external inputs.
set -euo pipefail
# The pinned OpenOrbis PkgTool.Core uses .NET without a bundled ICU package.
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ROOT="$(pwd)"
mkdir -p "$ROOT/build/ci/source" "$ROOT/build/ci/toolchain" "$ROOT/build/ci/dist" "$ROOT/build/ci/runtime"
echo "::group::Verify and prepare public OpenOrbis v0.5.4 toolchain"
curl --fail --location --retry 3 --retry-delay 5 --output "$ROOT/build/ci/toolchain.tar.gz" \
  "https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.4/toolchain-llvm-18.tar.gz"
echo "3c7cd5bb593ca74fa1c13fd59f3938dc0fc07985167f7275063019e63abe4526  $ROOT/build/ci/toolchain.tar.gz" | sha256sum -c -
tar -xzf "$ROOT/build/ci/toolchain.tar.gz" -C "$ROOT/build/ci/toolchain"
rm "$ROOT/build/ci/toolchain.tar.gz"
PKG_TOOL="$(find "$ROOT/build/ci/toolchain" -type f -path '*/bin/linux/PkgTool.Core' -print -quit)"
test -n "$PKG_TOOL"
chmod +x "$PKG_TOOL"
SDK_ROOT="$(dirname "$(dirname "$(dirname "$PKG_TOOL")")")"
test -f "$SDK_ROOT/include/orbis/libkernel.h" || test -d "$SDK_ROOT/include"
test -f "$SDK_ROOT/samples/hello_world/sce_sys/about/right.sprx"
echo "Pinned OpenOrbis toolchain located at $SDK_ROOT"
echo "::endgroup::"

echo "::group::Fetch pinned compiler inputs"
mkdir -p "$ROOT/build/ci/deps"
git clone --quiet https://github.com/sleirsgoevy/ps4-libjbc.git "$ROOT/build/ci/deps/libjbc"
git -C "$ROOT/build/ci/deps/libjbc" checkout --quiet 4dd18714fa7af7e15813d6a11537b60bb8c6f79c
git clone --quiet https://github.com/Scene-Collective/ps4-payload-sdk.git "$ROOT/build/ci/deps/payload-sdk"
git -C "$ROOT/build/ci/deps/payload-sdk" checkout --quiet b7326416c23ce14639e9180a24093bdc5eedb579
python3 releases/release-1.0/prepare-build.py --sdk "$SDK_ROOT" \
  --libjbc "$ROOT/build/ci/deps/libjbc" \
  --payload-sdk "$ROOT/build/ci/deps/payload-sdk" --output "$ROOT/build/ci/prepared"
echo "::endgroup::"

echo "::group::Acquire original 1.1 PKG and verify SHA256"
python3 tools/download-official-pkg.py --output "$ROOT/build/ci/source/Android-TV-for-PS4-1.1-b132.pkg"
"$PKG_TOOL" pkg_extract \
  "$ROOT/build/ci/source/Android-TV-for-PS4-1.1-b132.pkg" \
  "$ROOT/build/ci/source/extracted"
ASSETS="$(find "$ROOT/build/ci/source/extracted" -type d -name assets -print -quit)"
test -n "$ASSETS"
test -f "$ASSETS/initramfs.cpio.xz"
test -f "$ASSETS/bundled-apps.sfs"
python3 - "$ASSETS" <<'PY'
from pathlib import Path
import hashlib,json,sys
base=Path(sys.argv[1]); root=Path("releases/release-1.0")
runtime=json.loads((root/"runtime-inputs.json").read_text())
apps=json.loads((root/"bundled-apps-image.json").read_text())
checks={"initramfs.cpio.xz":runtime["initramfs_sha256"],
        "libgallium-baseline.so":runtime["mesa_sha256"],
        "bundled-apps.sfs":apps["sha256"],
        "mt7668-wifi.tar.gz":runtime["mt7668_wifi_sha256"]}
for name,expected in checks.items():
    h=hashlib.sha256()
    with (base/name).open("rb") as f:
        for chunk in iter(lambda:f.read(4194304),b""):h.update(chunk)
    assert h.hexdigest()==expected,(name,h.hexdigest(),expected)
    print("Verified input",name)
PY
rm "$ROOT/build/ci/source/Android-TV-for-PS4-1.1-b132.pkg"
echo "::endgroup::"

echo "::group::Repack snapshot runtime and build experimental PKG"
python3 releases/release-1.0/repack-runtime.py \
  --assets "$ASSETS" --output "$ROOT/build/ci/runtime"
python3 releases/release-1.0/build-release.py \
  --sdk "$SDK_ROOT" \
  --template "$ROOT/build/ci/prepared/template" \
  --objects "$ROOT/build/ci/prepared/objects" \
  --runtime "$(dirname "$PKG_TOOL")" \
  --assets "$ROOT/build/ci/runtime" \
  --probe-build "$ROOT/build/ci/prepared/payload" \
  --probe-linker "$ROOT/releases/release-1.0/helpers/linker.x" \
  --build "$ROOT/build/ci/package" \
  --output "$ROOT/build/ci/dist"
echo "::endgroup::"

echo "::group::Split PKG into hosted artifacts; preserve full SHA256"
mkdir -p "$ROOT/build/ci/pieces"
sha256sum "$ROOT/build/ci/dist/Android-TV-for-PS4.pkg" > "$ROOT/build/ci/pieces/SHA256SUMS"
split --bytes=1400M --numeric-suffixes=0 --suffix-length=2 \
  "$ROOT/build/ci/dist/Android-TV-for-PS4.pkg" \
  "$ROOT/build/ci/pieces/Android-TV-for-PS4.experimental.pkg.part-"
cat > "$ROOT/build/ci/pieces/JOIN-LINUX-MAC.txt" <<'EOF'
Experimental untested firmware 14.00 build. Do not install on your primary PS4.
cat Android-TV-for-PS4.experimental.pkg.part-* > Android-TV-for-PS4.pkg
sha256sum -c SHA256SUMS
EOF
cp "$ROOT/build/ci/dist/"{release.json,validation.txt} "$ROOT/build/ci/pieces/"
cp releases/release-1.0/runtime-inputs.json "$ROOT/build/ci/pieces/runtime-inputs.json"
cat "$ROOT/build/ci/pieces/SHA256SUMS"
ls -lh "$ROOT/build/ci/pieces"
echo "::endgroup::"
