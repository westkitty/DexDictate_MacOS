# Model Selection Closure — Validation

## Automated

- `swift build`: clean, exit 0.
- `swift test --filter WhisperModelCatalogTests`: 8/8 passed (2 updated for the new
  `(Multilingual)` display names, 6 unchanged).
- `swift test --filter ModelSelectionActionsTests`: 7/7 passed (6 from BUG-006 unchanged, 1 new:
  `testLegacyMultilingualInstallDoesNotMaskEnglishCatalogCounterpart`).
- `swift test` (full suite): **417 tests, 0 failures** — 416 pre-existing + 1 new, clean on
  first run, no known-flaky rerun needed. Log: `swift_test.log` in this directory.
- `./build.sh`: clean, exit 0. Built for production, signed, installed to
  `/Applications/DexDictate.app`.
- Relaunch verification: `pkill -x DexDictate_MacOS` then `open /Applications/DexDictate.app`;
  confirmed via `ps aux` that a single `DexDictate` process is running post-relaunch.

## Static checks

- `git diff --stat`: touches exactly `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`
  (the fix), `Tests/DexDictateTests/WhisperModelCatalogTests.swift`,
  `Tests/DexDictateTests/ModelSelectionActionsTests.swift` (both test-only), plus this packet's
  docs — plus pre-existing, unrelated `.resurrection/*` modifications that predate this session.
- `git diff -- <modified Swift files> | grep -i "AppStorage\|UserDefaults"`: no output — **no
  storage keys changed.**
- No forbidden files touched: no `Package.swift` change, no engine rewrite, no audio/output/
  insertion change, no default changes to Smart Cleanup/Live Preview, no removed engine support.
  `Parakeet`/`Nemotron`/`Moonshine`/`Apple Speech`/bundled/imported/downloaded Whisper support all
  unchanged.

## Filesystem inspection (real user data, read-only)

Confirmed via `find "$HOME/Library/Application Support/DexDictate" -maxdepth 6 -type f` and
cross-referenced against `debug.log`/`diagnostics.jsonl` — see `DIAGNOSIS.md` for the full
listing and log excerpts. No destructive action was taken; nothing was deleted, moved, or
renamed on disk.

## Manual validation checklist — **NEEDS_ANDREW**

I cannot personally click through this LSUIElement menu-bar app on the live desktop, and cannot
verify the exact on-screen wording change without you looking at it.

1. Open Settings → Models & Accuracy.
2. Scroll to "Model Library & Other Engines" → expand "Model Library" if collapsed.
3. Confirm your existing `ggml-base.bin`/`ggml-small.bin` models now show as **"Base
   (Multilingual)"** / **"Small (Multilingual)"** under "Installed Dictation Models" — still
   checkmarked as installed, just relabeled.
4. Confirm "Base English (142 MB)" / "Small English (466 MB)" still appear under "Download
   Models" — this is expected and correct; those specific English files genuinely aren't on disk.
   If you actually want the English variants, download them there; your existing "Base"/"Small"
   installs are untouched and still fully usable.
5. Confirm `medium.en (Imported)` is unaffected — still shows installed, unchanged label.
6. Confirm the "Active Dictation Model" top picker still lists your installed models correctly
   (Parakeet, tiny.en, and — if you ever pin Whisper — your installed sizes including the
   relabeled Multilingual ones).
7. Confirm dictation itself still works exactly as before — this fix only changes a label, not
   any inference/model-loading behavior.
