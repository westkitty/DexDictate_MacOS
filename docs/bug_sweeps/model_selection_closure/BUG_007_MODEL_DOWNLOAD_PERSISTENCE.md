# BUG-007 — Model Download "Persistence" (Display-Name Ambiguity)

## Root cause

Not a directory mismatch, not a filename→id mapping failure, not a missing-sidecar failure, not
a stale-catalog-refresh failure, and not a failed download — all five were checked against real
evidence (`~/Library/Application Support/DexDictate/` filesystem contents plus `debug.log`/
`diagnostics.jsonl`) and ruled out. Full trail in `DIAGNOSIS.md`.

The actual defect: two `ggml-base.bin`/`ggml-small.bin` files sitting in `Models/` (dated `Jun
18`, five days before BUG-006 — almost certainly fetched by hand via whisper.cpp's own
`download-ggml-model.sh`, which produces exactly that filename for the plain **multilingual**
size, not DexDictate's own download flow) are correctly recognized and correctly loaded as real,
working Whisper models — under ids `"base"`/`"small"`, displayed as bare `"Base"`/`"Small"`. The
app's own downloadable catalog separately offers `"base.en"`/`"small.en"` ("Base English"/"Small
English"), which have genuinely never been fetched. Shown side-by-side, `"Base"` (installed) and
`"Base English" (142 MB) — Download` (not installed) look like the same model, one claiming to
be there and one asking to be downloaded — reasonably read by a user as "it keeps forgetting I
downloaded this."

## Fix

`Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`,
`recognizedInstalledModel(fileName:)`: added a `stemsWithEnglishCatalogCounterpart` set
(`tiny`, `base`, `small`, `medium` — the four stems that have a real `.en` entry in
`downloadableCatalog`). A non-English recognized model whose stem is in that set now gets
`"(Multilingual)"` appended to its display name (`"Base"` → `"Base (Multilingual)"`), making it
visually unmistakable from its separately-tracked `.en` counterpart. `large`/`large-v1`/
`large-v2`/`large-v3` are untouched — none of them has an `.en` counterpart, so there was never
any ambiguity to resolve for them.

This does **not** change any id, any file path, any download behavior, or fake an installed
status for anything — `base.en`/`small.en` correctly continue to show "Download" (they
genuinely aren't there), and `"base"`/`"small"` correctly continue to show installed (they
genuinely are).

## Files changed

- `Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift` (the fix)
- `Tests/DexDictateTests/WhisperModelCatalogTests.swift` (updated display-name expectations for
  the four affected stems)
- `Tests/DexDictateTests/ModelSelectionActionsTests.swift` (new test:
  `testLegacyMultilingualInstallDoesNotMaskEnglishCatalogCounterpart`)

## Why this was missed by BUG-006

BUG-006 audited and fixed *binding* and *grouping* honesty (one active-model source of truth,
Installed/Download/Other-Engines sections) — it never inspected the real on-disk filesystem
state of a live user, only code paths and synthetic test fixtures. This defect only surfaces
when a real `ggml-<stem>.bin` (no `.en`) file already exists on disk from outside the app's own
download flow — a state BUG-006's testing never constructed, and BUG-006's protocol never asked
for a filesystem inspection the way this closure packet explicitly did.
