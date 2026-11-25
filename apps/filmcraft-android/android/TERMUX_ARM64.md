# FilmCraft: native ARM64 build on an Android phone

This is **not** the same thing as producing an ARM64 APK on an x86_64 PC.
It makes Gradle and the Rust compiler run on the **ARM64 phone itself**, in
**native Termux**. A Linux ARM64 PRoot distribution (Debian/Ubuntu) is a
different environment: its glibc binaries and SDK tools are not interchangeable
with Termux's Android/Bionic binaries.

## One-time prerequisites

1. Keep the Git checkout in the Termux home directory, **not** under
   `/sdcard` or `/storage/emulated/0` (those paths can be non-executable).
2. Install native Termux packages, for example:

   ```sh
   pkg update
   pkg install git bash openjdk-21 rust clang cmake aapt2
   ```

3. Install an **Android SDK with platform 37 and build-tools** in an
   accessible directory. The script searches `$HOME/.android-sdk` first when it
   contains API 37, then `$HOME/android-sdk`. Set `ANDROID_HOME` to override.
   The Android command-line tools' `sdkmanager` is one way to install
   `platforms;android-37.0` and
   `build-tools;36.0.0`. The current project requests **compileSdk 37**;
   ensure that your native ARM64 `aapt2` handles its resources.
   The official Linux build-tools from Google are usually **x86_64 host
   binaries**, so they cannot directly replace Termux's native `aapt2`.
4. Confirm that `rustc -vV` reports host `aarch64-linux-android`, that
   `aapt2 version` works, and that `java -version` reports a usable JDK.

## Build

From the repository root:

```sh
cd apps/filmcraft-android/android
export ANDROID_HOME="$HOME/.android-sdk"  # optional; the script auto-detects this path
bash build-termux-arm64.sh
```

The script validates ARM64 Termux tools and executes Gradle with:

```sh
./gradlew assembleDebug \
  -Pfilmcraft.termux=true \
  -Pfilmcraft.abis=arm64-v8a \
  "-Pandroid.aapt2FromMavenOverride=$(command -v aapt2)" \
  --no-daemon --max-workers=2 --no-parallel
```

After a successful build, the debug APK is at
`app/build/outputs/apk/debug/app-debug.apk`.

## How this differs from the default build

- On PCs and GitHub Actions, `CargoNdkBuild` still invokes
  `cargo ndk` and Google's original NDK, with **no behavior changes**.
- With `-Pfilmcraft.termux=true`, the Rust library is compiled using the
  Termux-native compiler for `aarch64-linux-android` and copied to the
  `arm64-v8a` JNI directory. The Kotlin bindings are still produced by UniFFI.
- The Gradle `aapt2` Maven override selects the **ARM64 native executable**.
  Native NDK stripping is skipped for this host mode because Google's
  `llvm-strip` for Linux is usually built for x86_64.
- The Q5_0 Whisper Large V3 Turbo model uses the `whisper-rs`/`whisper.cpp`
  C++ backend, which needs Termux-native `cmake` and `clang++`. The existing
  Whisper Tiny and Base models still run through the original Candle backend.
- Release signing and publication are **not** part of this script.
- The current root `rust-toolchain.toml` pins Rust **1.99.0** for desktop/CI;
  the Termux-packaged `rustc` and `cargo` must be compatible with the
  project's dependencies. A rustup-managed installation that cannot provide
  that version for the Termux host may need a native Termux Rust toolchain.

## Known limitations

This is an **unverified** host-build path; it was added without running a
build. In particular, the new whisper.cpp dependency has **not** been compiled
under Termux or with the Android NDK, and it may require further linker and
C++ standard-library adjustments. Native ARM64 `aapt2` alone may not be enough if Android Gradle Plugin
9.2.1 tries to invoke another x86_64-only tool. Third-party Rust build scripts
might also assume a desktop Linux NDK layout. The build needs enough free
storage and memory for Gradle, Rust and their caches. Diagnose the first
actual compiler failure before changing SDK or Rust versions.

The Gradle/Kotlin output **ABI** is already ARM64; this mode solves a
separate problem, the **host architecture** of the build tools.
