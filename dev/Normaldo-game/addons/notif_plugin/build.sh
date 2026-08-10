#!/usr/bin/env bash
# Builds notif_plugin.xcframework into ios/. Godot auto-detects the
# artifact via notif_plugin.gdextension on next Export Project.
#
# Usage:
#   GODOT_CPP=/Users/proc/Developer/godot-cpp ./build.sh
#   GODOT_CPP=... TARGET=template_debug ./build.sh
#
# Requires:
#   - godot-cpp checkout (branch 4.2) already built for iOS:
#       cd $GODOT_CPP
#       scons platform=ios target=template_release arch=arm64
#       scons platform=ios target=template_release arch=arm64 ios_simulator=yes
#       scons platform=ios target=template_release arch=x86_64 ios_simulator=yes
#   - scons, xcodebuild, libtool, lipo in PATH.

set -euo pipefail

cd "$(dirname "$0")"

GODOT_CPP="${GODOT_CPP:-/Users/proc/Developer/godot-cpp}"
TARGET="${TARGET:-template_release}"
BIN="bin"
OUT_DIR="ios"
OUT="$OUT_DIR/notif_plugin.xcframework"

if [[ ! -d "$GODOT_CPP/include/godot_cpp" || ! -d "$GODOT_CPP/gen/include/godot_cpp" ]]; then
  echo "ERROR: GODOT_CPP=$GODOT_CPP does not look like a godot-cpp checkout." >&2
  echo "       Expected include/godot_cpp/ and gen/include/godot_cpp/." >&2
  exit 1
fi

# godot-cpp ships matching .a slices we need to merge into ours so the
# final xcframework is self-contained.
expect_godot_cpp_slice() {
  local slice="$1"
  local f="$GODOT_CPP/bin/libgodot-cpp.ios.$TARGET.$slice.a"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f" >&2
    echo "       Run the godot-cpp build step described at the top of this script." >&2
    exit 1
  fi
  echo "$f"
}

GDCPP_ARM64_IOS="$(expect_godot_cpp_slice arm64)"
# godot-cpp emits simulator slices with a `.simulator` suffix in the
# filename. Detect both layouts (some godot-cpp versions diverge).
locate_godot_cpp_simulator() {
  local arch="$1"
  for f in \
    "$GODOT_CPP/bin/libgodot-cpp.ios.$TARGET.$arch.simulator.a" \
    "$GODOT_CPP/bin/libgodot-cpp.ios.$TARGET.simulator.$arch.a"; do
    if [[ -f "$f" ]]; then echo "$f"; return; fi
  done
  echo "ERROR: missing libgodot-cpp simulator .a for arch=$arch in $GODOT_CPP/bin/" >&2
  exit 1
}
GDCPP_ARM64_SIM="$(locate_godot_cpp_simulator arm64)"
GDCPP_X86_64_SIM="$(locate_godot_cpp_simulator x86_64)"

if ! command -v scons >/dev/null 2>&1; then
  echo "ERROR: scons not found in PATH." >&2
  exit 1
fi

echo "→ Cleaning $BIN/"
rm -rf "$BIN"
mkdir -p "$BIN" "$OUT_DIR"

build_slice() {
  local arch="$1" sim="$2"
  echo "→ scons arch=$arch simulator=$sim target=$TARGET"
  scons -Q \
    arch="$arch" \
    simulator="$sim" \
    target="$TARGET" \
    godot_cpp="$GODOT_CPP" \
    target_path="$BIN/"
}

build_slice arm64  no
build_slice arm64  yes
build_slice x86_64 yes

# Merge our slice with godot-cpp's matching slice so the final library is
# self-contained. libtool -static collects every .o from every input .a.
merge_slice() {
  local out="$1"; shift
  echo "→ libtool merge → $(basename "$out")"
  libtool -static -o "$out" "$@"
}

ARM64_IOS_FAT="$BIN/libnotif_plugin.arm64-ios.$TARGET.merged.a"
ARM64_SIM_FAT="$BIN/libnotif_plugin.arm64-simulator.$TARGET.merged.a"
X86_64_SIM_FAT="$BIN/libnotif_plugin.x86_64-simulator.$TARGET.merged.a"

merge_slice "$ARM64_IOS_FAT" \
  "$BIN/libnotif_plugin.arm64-ios.$TARGET.a" \
  "$GDCPP_ARM64_IOS"
merge_slice "$ARM64_SIM_FAT" \
  "$BIN/libnotif_plugin.arm64-simulator.$TARGET.a" \
  "$GDCPP_ARM64_SIM"
merge_slice "$X86_64_SIM_FAT" \
  "$BIN/libnotif_plugin.x86_64-simulator.$TARGET.a" \
  "$GDCPP_X86_64_SIM"

# lipo the two simulator slices together (arm64 sim + x86_64 sim).
SIM_FAT="$BIN/libnotif_plugin-simulator.$TARGET.merged.a"
echo "→ lipo simulator slices"
lipo -create "$ARM64_SIM_FAT" "$X86_64_SIM_FAT" -output "$SIM_FAT"

echo "→ assembling $OUT"
rm -rf "$OUT"
xcodebuild -create-xcframework \
  -library "$ARM64_IOS_FAT" \
  -library "$SIM_FAT" \
  -output "$OUT"

echo
echo "✓ Built $OUT"
echo "  Re-export the iOS project from Godot — notif_plugin.gdextension is auto-detected."
