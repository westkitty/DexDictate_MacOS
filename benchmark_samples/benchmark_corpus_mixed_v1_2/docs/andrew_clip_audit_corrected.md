# Corrected DexDictate Benchmark Corpus v2 Audio Audit

Correction: this audit does **not** prove what was actually spoken. It checks whether each clip duration is plausible for the expected transcript in `transcripts.json`. High WPM therefore means transcript/duration mismatch risk, not necessarily actual speech rate.

## Summary

- DURATION_SANITY_OK: 36
- FAST_BUT_PLAUSIBLE_REVIEW: 9
- HARD_TRANSCRIPT_DURATION_MISMATCH: 5

## Hard transcript/duration mismatches

- 23 `audio/023_punctuation_heavy.wav` — 1.34s, 11 words, 492.5 WPM if manifest is correct. Expected: First, test the baseline; second, compare the engines; third, refuse nonsense.
- 33 `audio/033_quiet_speech.wav` — 1.59s, 11 words, 415.1 WPM if manifest is correct. Expected: Quiet dictation is difficult because the signal is weaker than normal.
- 36 `audio/036_fast_speech.wav` — 2.34s, 17 words, 435.9 WPM if manifest is correct. Expected: I am speaking a little faster now to see whether the model keeps up with normal thought.
- 45 `audio/045_background_noise.wav` — 0.94s, 13 words, 829.8 WPM if manifest is correct. Expected: The noisy section is complete, and the final words should still be clear.
- 46 `audio/046_silence_clipping.wav` — 1.19s, 9 words, 453.8 WPM if manifest is correct. Expected: After this sentence, there will be a longer silence.

## Fast but plausible / review, not discard by math alone

- 01 `audio/001_normal_dictation.wav` — 4.44s, 19 words, 256.8 WPM. Expected: DexDictate is running in the menu bar, and I want this sentence to appear exactly where my cursor is.
- 05 `audio/005_normal_dictation.wav` — 4.59s, 19 words, 248.4 WPM. Expected: I need the transcript copied to the clipboard, but I do not want it pasted into the wrong field.
- 22 `audio/022_punctuation_heavy.wav` — 3.54s, 14 words, 237.3 WPM. Expected: The problem is simple: the model is fast, but the benchmark is too small.
- 24 `audio/024_punctuation_heavy.wav` — 3.94s, 17 words, 258.9 WPM. Expected: Do not guess, do not hype, and do not change the app until the numbers justify it.
- 32 `audio/032_quiet_speech.wav` — 2.59s, 11 words, 254.8 WPM. Expected: The app should still capture quiet speech without inventing extra words.
- 34 `audio/034_quiet_speech.wav` — 2.69s, 12 words, 267.7 WPM. Expected: This is a soft sentence with proper nouns: Dexter, BigMac, and DexDictate.
- 37 `audio/037_fast_speech.wav` — 2.99s, 13 words, 260.9 WPM. Expected: Sometimes I dictate quickly because stopping to speak carefully ruins the whole workflow.
- 42 `audio/042_background_noise.wav` — 3.29s, 15 words, 273.6 WPM. Expected: The model should ignore the room and focus on the words I am actually saying.
- 44 `audio/044_background_noise.wav` — 3.39s, 14 words, 247.8 WPM. Expected: DexDictate needs to work even when a fan, keyboard, or room sound is present.

## Duration sanity OK by math alone

- 02 `audio/002_normal_dictation.wav` — 5.44s, 16 words, 176.5 WPM.
- 03 `audio/003_normal_dictation.wav` — 4.39s, 14 words, 191.3 WPM.
- 04 `audio/004_normal_dictation.wav` — 4.24s, 16 words, 226.4 WPM.
- 06 `audio/006_normal_dictation.wav` — 3.19s, 12 words, 225.7 WPM.
- 07 `audio/007_normal_dictation.wav` — 4.19s, 16 words, 229.1 WPM.
- 08 `audio/008_normal_dictation.wav` — 5.99s, 18 words, 180.3 WPM.
- 09 `audio/009_normal_dictation.wav` — 3.79s, 12 words, 190.0 WPM.
- 10 `audio/010_normal_dictation.wav` — 4.39s, 14 words, 191.3 WPM.
- 11 `audio/011_proper_nouns.wav` — 4.19s, 9 words, 128.9 WPM.
- 12 `audio/012_proper_nouns.wav` — 4.09s, 13 words, 190.7 WPM.
- 13 `audio/013_proper_nouns.wav` — 6.74s, 13 words, 115.7 WPM.
- 14 `audio/014_proper_nouns.wav` — 6.54s, 13 words, 119.3 WPM.
- 15 `audio/015_proper_nouns.wav` — 4.19s, 9 words, 128.9 WPM.
- 16 `audio/016_command_like.wav` — 0.69s, 2 words, 173.9 WPM.
- 17 `audio/017_command_like.wav` — 0.69s, 2 words, 173.9 WPM.
- 18 `audio/018_command_like.wav` — 2.14s, 6 words, 168.2 WPM.
- 19 `audio/019_command_like.wav` — 2.74s, 6 words, 131.4 WPM.
- 20 `audio/020_command_like.wav` — 4.44s, 14 words, 189.2 WPM.
- 21 `audio/021_punctuation_heavy.wav` — 5.14s, 17 words, 198.4 WPM.
- 25 `audio/025_punctuation_heavy.wav` — 5.69s, 8 words, 84.4 WPM.
- 26 `audio/026_technical.wav` — 3.94s, 12 words, 182.7 WPM.
- 27 `audio/027_technical.wav` — 4.19s, 14 words, 200.5 WPM.
- 28 `audio/028_technical.wav` — 6.04s, 22 words, 218.5 WPM.
- 29 `audio/029_technical.wav` — 6.29s, 11 words, 104.9 WPM.
- 30 `audio/030_technical.wav` — 4.99s, 13 words, 156.3 WPM.
- 31 `audio/031_quiet_speech.wav` — 5.19s, 11 words, 127.2 WPM.
- 35 `audio/035_quiet_speech.wav` — 5.29s, 10 words, 113.4 WPM.
- 38 `audio/038_fast_speech.wav` — 8.99s, 12 words, 80.1 WPM.
- 39 `audio/039_fast_speech.wav` — 3.79s, 14 words, 221.6 WPM.
- 40 `audio/040_fast_speech.wav` — 4.04s, 14 words, 207.9 WPM.
- 41 `audio/041_background_noise.wav` — 6.99s, 9 words, 77.3 WPM.
- 43 `audio/043_background_noise.wav` — 3.99s, 14 words, 210.5 WPM.
- 47 `audio/047_silence_clipping.wav` — 3.59s, 9 words, 150.4 WPM.
- 48 `audio/048_silence_clipping.wav` — 3.24s, 8 words, 148.1 WPM.
- 49 `audio/049_silence_clipping.wav` — 3.09s, 7 words, 135.9 WPM.
- 50 `audio/050_silence_clipping.wav` — 4.67s, 7 words, 89.9 WPM.
