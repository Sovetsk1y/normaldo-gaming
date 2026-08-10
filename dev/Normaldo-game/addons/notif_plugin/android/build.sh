#!/usr/bin/env bash
# Builds NotifPluginAndroid.aar and drops it next to its .gdap descriptor in
# res://android/plugins/, where the Godot iOS-style exporter picks it up during
# an Android export (custom gradle build must be enabled).
#
# Usage:
#   ./build.sh            # release AAR (default)
#   ./build.sh debug      # debug AAR
#
# Requires: JDK 17 on PATH (or JAVA_HOME). No system gradle needed — the wrapper
# (copied from the Godot 4.2.2 android template) downloads gradle 8.2 on first run.

set -euo pipefail
cd "$(dirname "$0")"

VARIANT="${1:-release}"
case "$VARIANT" in
  release) TASK="assembleRelease"; AAR_SUFFIX="release" ;;
  debug)   TASK="assembleDebug";   AAR_SUFFIX="debug" ;;
  *) echo "ERROR: unknown variant '$VARIANT' (use release|debug)" >&2; exit 1 ;;
esac

DEST="../../../android/plugins"   # res://android/plugins relative to this dir
OUT_AAR="build/outputs/aar/notif_plugin_android-${AAR_SUFFIX}.aar"

# gradle needs the Android SDK path. Honour ANDROID_HOME / ANDROID_SDK_ROOT,
# else fall back to the macOS default, and write it to local.properties (which
# is gitignored) so the wrapper build is self-contained.
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
if [[ ! -d "$SDK_DIR" ]]; then
  echo "ERROR: Android SDK not found at '$SDK_DIR'." >&2
  echo "       Set ANDROID_HOME or install the SDK." >&2
  exit 1
fi
echo "sdk.dir=$SDK_DIR" > local.properties
echo "→ using Android SDK: $SDK_DIR"

echo "→ ./gradlew $TASK"
./gradlew --no-daemon "$TASK"

if [[ ! -f "$OUT_AAR" ]]; then
  echo "ERROR: expected AAR not found at $OUT_AAR" >&2
  exit 1
fi

mkdir -p "$DEST"
cp "$OUT_AAR" "$DEST/NotifPluginAndroid.aar"
echo
echo "✓ Built and installed $DEST/NotifPluginAndroid.aar"
echo "  Enable custom gradle build + the NotifPluginAndroid plugin in the"
echo "  Android export preset, then export."
