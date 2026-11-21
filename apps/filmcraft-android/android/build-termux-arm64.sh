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

for tool in java cargo rustc clang aapt2; do
  command -v "$tool" >/dev/null 2>&1 ||
    fail "Missing $tool. Install Termux packages (openjdk-21, rust, clang, aapt2)."
done

rust_host="$(rustc -vV | sed -n 's/^host: //p')"
[[ "$rust_host" == "aarch64-linux-android" ]] ||
  fail "Rust host is '$rust_host', but native Termux needs aarch64-linux-android. Use the Termux rust package."

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
[[ -f "$ANDROID_HOME/platforms/android-37/android.jar" ]] ||
  fail "Android SDK platform 37 is missing under $ANDROID_HOME. Install platforms;android-37 (and SDK build-tools) first."
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

printf 'Host: %s | Rust: %s | SDK: %s | aapt2: %s\n' \
  "$(uname -m)" "$rust_host" "$ANDROID_HOME" "$aapt2_path"

./gradlew assembleDebug \
  "-Pfilmcraft.termux=true" \
  "-Pfilmcraft.abis=arm64-v8a" \
  "-Pandroid.aapt2FromMavenOverride=$aapt2_path" \
  --no-daemon --max-workers=2 --no-parallel \
  "$@"

printf 'APK: %s\n' "$PWD/app/build/outputs/apk/debug/app-debug.apk"
