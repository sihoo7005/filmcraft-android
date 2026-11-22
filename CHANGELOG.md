# FilmCraft Android change log

This log tracks the Android app's development builds. The version shown in
**Settings > About FilmCraft** comes from `apps/filmcraft-android/android/gradle.properties`.

## 0.0.2-beta.2 (2026-11-22)

- **Timeline:** Fix the preview when dragging a video's left trim handle. Thumbnails and audio waveform stay anchored while the visible edge changes; the duration badge previews the resulting length.
- **Captions:** Add time-based and text-at-cursor splitting; support long-press dragging to move captions or trim their start/end times.
- **Timeline controls:** Tapping a clip selects it without moving the playhead.
- **Text:** Add Android system-font fallback for Korean subtitle glyphs.
- **Android ARM64 development:** Add a native Termux build entry point and SDK path discovery for `~/.android-sdk` and `android-37.0`. This host build path is not yet verified on a device.

These are source-code changes. A successful APK build and device testing are
still required to verify the current development version.

## 0.0.2-beta (previous version)

Earlier beta version. The notes above describe changes accumulated since that
version in this fork.

## Versioning

- Increment the Android development version **with each user-visible feature
  or bug-fix batch**, and add an entry here in the same change.
- While on `0.0.2-beta`, use `0.0.2-beta.2`, `0.0.2-beta.3`, etc.
  After `.98`, start a new patch version (e.g. `0.0.3-beta`).
- Update both `filmcraft.version` and `filmcraft.versionCode` in
  `apps/filmcraft-android/android/gradle.properties`. Gradle validates their
  consistency. For `0.0.2-beta.2`, the base version code is `202`; an
  ARM64-only APK uses version code `2022`.
- A version bump does **not** mean a build ran or an APK was released.
