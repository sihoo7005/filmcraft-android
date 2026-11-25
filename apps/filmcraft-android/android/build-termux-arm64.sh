#!/data/data/com.termux/files/usr/bin/bash
# Build FilmCraft's debug APK on the phone itself (native Termux / Android ARM64).
# This script is never called by GitHub Actions or by ordinary desktop builds.
set -euo pipefail

fail() {
  printf 'FilmCraft Termux ARM64: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -m)" == "aarch64" ]] || fail "This script requires an ARM64/aarch64 host."
[[ -n "${PREFIX:-}" && "${PREFIX}" == *"/com.termux/files/usr" ]] ||
  fail "Use Termux itself, not Ubuntu/Debian PRoot. Those need a different host toolchain."

# The optional quantized Whisper backend compiles whisper.cpp via CMake/C++.
for tool in java cargo rustc clang clang++ cmake aapt2; do
  command -v "$tool" >/dev/null 2>&1 ||
    fail "Missing $tool. Install Termux packages (openjdk-21, rust, clang, cmake, aapt2)."
done

rust_host="$(rustc -vV | sed -n 's/^host: //p')"
[[ "$rust_host" == "aarch64-linux-android" ]] ||
  fail "Rust host is '$rust_host', but native Termux needs aarch64-linux-android. Use the Termux rust package."

# Respect an explicitly chosen SDK. Otherwise prefer the installed Termux SDK,
# including the ~/.android-sdk directory used by some phone setups.
if [[ -n "${ANDROID_HOME:-}" ]]; then
  sdk_root="$ANDROID_HOME"
elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
  sdk_root="$ANDROID_SDK_ROOT"
elif [[ -f "$HOME/.android-sdk/platforms/android-37.0/android.jar" ||
        -f "$HOME/.android-sdk/platforms/android-37/android.jar" ]]; then
  sdk_root="$HOME/.android-sdk"
else
  sdk_root="$HOME/android-sdk"
fi
export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"

# API 37 is packaged as android-37.0 by newer Android SDK managers.
if [[ -f "$ANDROID_HOME/platforms/android-37.0/android.jar" ]]; then
  sdk_platform="$ANDROID_HOME/platforms/android-37.0"
elif [[ -f "$ANDROID_HOME/platforms/android-37/android.jar" ]]; then
  sdk_platform="$ANDROID_HOME/platforms/android-37"
else
  fail "Android SDK platform 37 is missing under $ANDROID_HOME (expected platforms/android-37.0 or android-37)."
fi
[[ -d "$ANDROID_HOME/build-tools" ]] ||
  fail "Android SDK build-tools are missing under $ANDROID_HOME."

# The Android Gradle Plugin otherwise fetches Google's Linux x86_64 aapt2.
aapt2_path="${FILMCRAFT_AAPT2:-$(command -v aapt2)}"
[[ -x "$aapt2_path" ]] || fail "ARM64 aapt2 is not executable: $aapt2_path"
"$aapt2_path" version >/dev/null 2>&1 ||
  fail "aapt2 failed to run. Use the native Termux aapt2 package."

# Use native Termux's Rust, Clang and linker, never an x86_64 NDK prebuilt.
export CARGO="$(command -v cargo)"
export CC="${CC:-$(command -v clang)}"
export CXX="${CXX:-$(command -v clang++)}"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER:-$(command -v clang)}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}"
export GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.native=false -Dorg.gradle.vfs.watch=false"

cd "$(dirname "$0")"
[[ -x ./gradlew ]] || chmod +x ./gradlew

printf 'Host: %s | Rust: %s | SDK: %s | Platform: %s | aapt2: %s\n' \
  "$(uname -m)" "$rust_host" "$ANDROID_HOME" "$sdk_platform" "$aapt2_path"

./gradlew assembleDebug \
  "-Pfilmcraft.termux=true" \
  "-Pfilmcraft.abis=arm64-v8a" \
  "-Pandroid.aapt2FromMavenOverride=$aapt2_path" \
  --no-daemon --max-workers=2 --no-parallel \
  "$@"

printf 'APK: %s\n' "$PWD/app/build/outputs/apk/debug/app-debug.apk"
