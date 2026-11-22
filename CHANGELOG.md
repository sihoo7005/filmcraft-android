# FilmCraft Android change log

This log tracks the Android app's development builds. The version shown in
**Settings > About FilmCraft** comes from `apps/filmcraft-android/android/gradle.properties`.

## 0.0.2-beta.7 (2026-11-22)

- **Video-caption follow toggle:** Select a video on the main track and tap the `Captions off/on` tool to control whether captions move with that video. The default is off, so captions stay at their chosen times.
- **Selective linking:** When enabled, only captions whose start time was inside the grabbed video's original time range follow the video's horizontal move or reorder. Other captions remain fixed; linked source audio retains its existing behavior.
- **Safe, undoable edits:** Apply video and caption movement as a single undo step. If a linked caption would overlap another caption, reject and roll back the entire drag rather than truncating or losing text.
- Add Rust regression cases for enabled moves and reorders, unrelated caption isolation, collision rollback, undo and redo.

This is an editor toggle rather than a persisted project-level caption association. Source change only; no APK build or device test was performed.

## 0.0.2-beta.6 (2026-11-22)

- **Independent subtitle timing:** Moving a video horizontally into an empty gap no longer drags its captions along. Captions keep their existing start/end times.
- **Video reorder:** Temporarily disable caption-track sync-lock ripple during video reordering so dragging across another clip does not shift or split subtitles.
- **Linked source audio:** Continue moving a video's own linked audio with it; this is separate from subtitle timing.
- Add regression checks for both move and reorder with caption positions preserved across undo.

Source change only; no APK build or device testing was performed.

## 0.0.2-beta.5 (2026-11-22)

- **Draggable timeline origin:** Long-press the blue handle at the ruler's `0:00` mark, then drag it horizontally to reposition time zero independently of video clips.
- **Live preview:** The ruler labels move under the finger while video, audio and caption drawings stay in place. Nearby clip starts are magnetic snap targets.
- **Real timeline rebase:** On release, shift clip positions on all video/audio lanes, captions, transitions, sequence markers, in/out marks and the work-area start together. Recalculate the playhead and project duration for playback and export.
- **Safety:** Prevent moving any timed content before zero; moving the marker left can deliberately add leading space. This operation creates a single undoable timeline edit.
- Add Rust regression tests for linked audio, captions, markers, in/out marks, clamping, undo and redo.

Source change only; no APK build or device test was performed.

## 0.0.2-beta.4 (2026-11-22)

- **Video timeline:** Fix the case where a long-pressed video appears to move horizontally during the drag but snaps back after release.
- **True position moves:** A main-track video can now be placed at a new, unoccupied timeline time, including when there is only one video. Empty gaps remain empty instead of forcing the clip back to its original slot.
- **Multiple videos:** If a dropped video would overlap another video, use the existing reorder behavior rather than overwriting that other video. The drag preview no longer suggests movement for a collision that leaves the reorder slot unchanged.
- **Linked audio:** Move linked audio with the video; reject free moves that would overwrite unrelated audio. Edits remain undoable.
- Add Rust and Kotlin regression tests for empty-gap moves, overlap protection and undo.

Source change only; the APK has not been built or tested on a device.

## 0.0.2-beta.3 (2026-11-22)

- **Video timeline:** Keep main-track clip drag previews on the same horizontal lane; overlay and audio clips still support vertical lane moves.
- **Reordering:** Fix target-position calculations using clips' original centres. A long press without horizontal movement must not unexpectedly reorder a clip.
- **Feedback:** Show an insertion marker when a dragged main-track clip crosses another clip's reorder threshold.
- **Expected behavior:** The main video lane remains a gap-free, reorder-only track. One clip alone has no reorder destination.

Source change only; the APK has not been built or tested on a device.

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
