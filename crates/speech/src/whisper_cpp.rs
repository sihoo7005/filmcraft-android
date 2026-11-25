//! Quantized Whisper GGML inference via whisper.cpp (whisper-rs).
//! Unlike the Candle path, this accepts ggml *-q5_0.bin models directly.
//! It is intentionally opt-in: adding this feature brings in a C++/CMake
//! native build, which Android packaging must provide.

use std::path::Path;

use filmcraft_project::{Transcript, Word};
use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

use crate::{Options, ProgressFn, SAMPLE_RATE, SpeechError, Transcriber, sample_tick};

const WINDOW_SAMPLES: usize = 30 * SAMPLE_RATE as usize;
const SAMPLES_PER_CENTISECOND: i64 = SAMPLE_RATE as i64 / 100;

fn model_error(e: impl std::fmt::Display) -> SpeechError {
    SpeechError::Model(e.to_string())
}

/// The model lives in the app's verified download directory. Never load an
/// arbitrary path or duplicate hundreds of megabytes of weights into Rust.
pub struct WhisperCpp {
    id: String,
    context: WhisperContext,
}

impl WhisperCpp {
    pub fn load(dir: &Path, id: &str) -> Result<Self, SpeechError> {
        let path = dir.join("ggml-large-v3-turbo-q5_0.bin");
        let path = path.to_str().ok_or_else(|| SpeechError::Model("Invalid model path.".into()))?;
        let context = WhisperContext::new_with_params(path, WhisperContextParameters::default()).map_err(model_error)?;
        Ok(Self { id: id.into(), context })
    }
}

fn tick_cs(cs: i64) -> filmcraft_time::Tick {
    sample_tick(cs.saturating_mul(SAMPLES_PER_CENTISECOND))
}

/// A word may span several UTF-8-fragmented Whisper tokens. Merge raw bytes
/// *before* decoding to avoid replacing half a Korean or Japanese character.
fn push_word(words: &mut Vec<Word>, bytes: &mut Vec<u8>, start: i64, end: i64, offset_samples: i64) {
    if bytes.is_empty() {
        return;
    }
    let text = String::from_utf8_lossy(bytes).trim().to_owned();
    bytes.clear();
    if text.is_empty() {
        return;
    }
    let offset = sample_tick(offset_samples);
    let a = tick_cs(start.max(0)) + offset;
    let b = tick_cs(end.max(start + 1)) + offset;
    words.push(Word::new(text, a, b));
}

fn words_for_segment(segment: &whisper_rs::WhisperSegment<'_>, offset_samples: i64, out: &mut Vec<Word>) {
    let mut bytes = Vec::<u8>::new();
    let mut begin = segment.start_timestamp().max(0);
    let mut end = begin;
    for i in 0..segment.n_tokens() {
        let Some(token) = segment.get_token(i) else { continue };
        let Ok(token_bytes) = token.to_bytes() else { continue };
        if token_bytes.is_empty() || token_bytes.starts_with(b"<|") {
            continue;
        }
        let d = token.token_data();
        let t0 = if d.t0 >= 0 && d.t1 > d.t0 { d.t0 } else { segment.start_timestamp() };
        let t1 = if d.t0 >= 0 && d.t1 > d.t0 { d.t1 } else { segment.end_timestamp() };
        // Word boundaries in multilingual Whisper are ordinary ASCII spaces.
        // Byte-by-byte splitting also handles embedded spaces without corrupting UTF-8.
        for &b in token_bytes {
            if b.is_ascii_whitespace() {
                push_word(out, &mut bytes, begin, t0.max(end), offset_samples);
            } else {
                if bytes.is_empty() {
                    begin = t0.max(0);
                    end = t1.max(begin + 1);
                } else {
                    end = end.max(t1);
                }
                bytes.push(b);
            }
        }
    }
    push_word(out, &mut bytes, begin, end.max(segment.end_timestamp()), offset_samples);
}

impl Transcriber for WhisperCpp {
    fn id(&self) -> String {
        self.id.clone()
    }

    fn transcribe(&self, audio: &[f32], opts: &Options, progress: ProgressFn) -> Result<Transcript, SpeechError> {
        if !progress(0.0, "Preparing quantized Whisper Turbo") {
            return Err(SpeechError::Cancelled);
        }
        let mut words = Vec::new();
        let mut language = opts.language.as_deref().filter(|l| !l.is_empty() && *l != "auto").map(str::to_owned);
        for (i, chunk) in audio.chunks(WINDOW_SAMPLES).enumerate() {
            let offset_samples = i.saturating_mul(WINDOW_SAMPLES) as i64;
            let fraction = offset_samples as f32 / audio.len().max(1) as f32;
            if !progress(fraction * 0.95, "Transcribing with Whisper Turbo") {
                return Err(SpeechError::Cancelled);
            }
            let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
            params.set_language(language.as_deref());
            params.set_translate(false);
            params.set_token_timestamps(true);
            params.set_split_on_word(true);
            params.set_print_progress(false);
            params.set_print_realtime(false);
            params.set_print_timestamps(false);
            params.set_n_threads(4);
            // An isolated 30 s window keeps native memory bounded and provides
            // progress/cancel points between windows.
            let mut state = self.context.create_state().map_err(model_error)?;
            state.full(params, chunk).map_err(model_error)?;
            if language.is_none() {
                language = whisper_rs::get_lang_str(state.full_lang_id_from_state()).map(str::to_owned);
            }
            for segment in state.as_iter() {
                words_for_segment(&segment, offset_samples, &mut words);
            }
        }
        let mut t = Transcript {
            language: language.unwrap_or_else(|| "en".into()),
            source: self.id.clone(),
            speakers: Vec::new(),
            words,
        };
        t.normalize();
        crate::vad::tighten_words(audio, &mut t.words);
        if opts.diarize && !t.words.is_empty() {
            if !progress(0.96, "Labelling speakers") {
                return Err(SpeechError::Cancelled);
            }
            let p = crate::diarize::Params { max_speakers: opts.max_speakers, ..Default::default() };
            crate::diarize::diarize(audio, &mut t, &p);
        }
        if !progress(1.0, "Done") {
            return Err(SpeechError::Cancelled);
        }
        Ok(t)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn utf8_fragments_combine_before_word_decoding() {
        let mut words = Vec::new();
        let mut bytes = vec![0xED, 0x95];
        bytes.push(0x9C); // "한"
        push_word(&mut words, &mut bytes, 10, 25, 0);
        assert_eq!(words.len(), 1);
        assert_eq!(words[0].text, "한");
        assert_eq!(words[0].start, tick_cs(10));
        assert_eq!(words[0].end, tick_cs(25));
    }
}
