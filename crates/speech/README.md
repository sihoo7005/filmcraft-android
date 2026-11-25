# filmcraft-speech

Speech-to-text for FilmCraft's Text panel ▸ Transcript (L2). User-facing behaviour, commands and
model handling: [docs/transcripts.md](../../docs/transcripts.md).

- `Transcriber` trait (mono 16 kHz in, word-timed `filmcraft_project::Transcript` out) and
  `FixedTranscriber` for tests and agents.
- `models`: Whisper model catalogue (pinned revisions, SHA-256, sizes, licences) and, with feature
  `download`, the verified downloader (ureq + rustls + RustCrypto). Weights are never bundled.
- `whisper` (feature `whisper`): Whisper inference on candle (CPU, pure Rust).
- `mel`, `vad`, `diarize`: log-mel front end, word-bound tightening, MFCC-clustering speaker labels.

The existing `whisper` feature loads safetensors through the pure-Rust Candle CPU
backend. The separate, optional `whisper-cpp` feature loads GGML quantized weights through
`whisper-rs` / `whisper.cpp` (native C++/CMake); it must **not** be used to load
safetensors models.

The Android app enables both backends and offers Tiny, Base and **Large V3 Turbo Q5_0**
(model ID `whisper-large-v3-turbo-q5_0`). The Turbo model is about 547 MiB on
disk (574,041,195 bytes); the download URL is pinned to its Hugging Face upload
commit and validated against SHA-256 before use. Unlike Tiny/Base, Turbo
requires significantly more RAM and CPU. Its Android build, runtime behavior,
word timestamps and recognition speed **have not been verified**. The model
is fetched only after the user confirms and is not packaged in the APK.

All inference features are off by default for the general workspace and are not
enabled for wasm (`cargo xtask wasm` checks the crate without them).

## References

Implemented from the published description of the model: A. Radford et al., "Robust Speech
Recognition via Large-Scale Weak Supervision" (OpenAI, 2022), the model cards and configuration
files published with the weights (`config.json`, `generation_config.json`, `tokenizer.json`), and
the candle tensor library's public API. Weights: OpenAI Whisper, MIT licence.
