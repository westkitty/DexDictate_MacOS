# BUG-007 Diagnosis — "Downloaded models keep appearing as needing Download"

## Filesystem evidence (real user data, inspected read-only)

`find "$HOME/Library/Application Support/DexDictate" -maxdepth 6 -type f`:

```
Models/ggml-base.bin          141 MB   Jun 18 04:07
Models/ggml-small.bin         465 MB   Jun 18 04:09
Models/medium.en.bin         1462 MB   Jul  5 12:48
ModelMetadata/medium.en.json           Jul  5 12:48
```

Only `medium.en` has a metadata sidecar. `debug.log`/`diagnostics.jsonl` confirm all three files
load successfully as real Whisper models in production use (`"Loading Whisper model from
.../ggml-base.bin (141 MB)... Whisper model loaded successfully"`, same for `ggml-small.bin` and
`medium.en.bin`). **No download failure of any kind appears anywhere in the logs** — no `"Failed
to download"`, no `Whisper model download failed`, nothing. This rules out a silent
download-failure loop as the cause.

## 1. Where does DexDictate scan for installed Whisper models?

`WhisperModelCatalog.refresh()` (`Sources/DexDictateKit/Benchmarking/WhisperModelCatalog.swift`):
bundled `tiny.en` (from the app bundle resource) → imported models (via metadata sidecar in
`ModelMetadata/`) → `scanInstalledModelFiles()`, which lists everything directly inside
`Models/` and keeps files matching `recognizedInstalledModel(fileName:)`.

## 2. Where does `downloadModel(...)` save downloaded models?

`modelsDirectoryURL.appendingPathComponent("\(entry.id).bin")` — e.g. downloading catalog entry
`base.en` saves to `Models/base.en.bin`, with a matching `ModelMetadata/base.en.json` sidecar.

## 3. Where do imported models live?

Same `Models/` directory, filename = the imported file's own original name (`importModel`
requires it to already be named `base.en.bin` or `small.en.bin`), same
`ModelMetadata/<id>.json` sidecar scheme as downloads.

## 4. Where do bundled models live?

`tiny.en` only, inside the app bundle's `DexDictateKit` resource bundle (`tiny.en.bin`) —
confirmed in logs loading from both
`.build/.../DexDictate_MacOS_DexDictateKit.bundle/tiny.en.bin` (debug builds) and
`/Applications/DexDictate.app/Contents/Resources/.../tiny.en.bin` (installed builds). This is
expected to differ by build location — it's a read-only bundle resource, never a
user-downloaded model, and doesn't affect `Models/` at all.

## 5. Does the scan path match the download path?

**Yes.** Both read/write `modelsDirectoryURL` (`supportDirectoryURL/Models`), and
`supportDirectoryURL` resolves to `~/Library/Application Support/DexDictate` — not sandboxed
(`DexDictate.entitlements` only requests audio-input/input-monitoring, no
`com.apple.security.app-sandbox`), so this path is identical across debug and production builds
and confirmed identical in the logs above (both `medium.en.bin` and `ggml-base.bin` load from
the same `~/Library/Application Support/DexDictate/Models/` regardless of which build launched
them). **Not a directory-mismatch bug.**

## 6. Does reinstalling/rebuilding the app change the model path?

No — confirmed by the logs above; `Models/` is a stable, non-sandboxed, non-bundle-relative path.
Only the *bundled* `tiny.en.bin` resource path differs between debug/production, which is
expected and unrelated to user-downloaded/imported models.

## 7. Expected filenames

| Model | App's own download/import filename | Legacy whisper.cpp `download-ggml-model.sh` filename |
|---|---|---|
| tiny.en | `tiny.en.bin` | `ggml-tiny.en.bin` |
| base (multilingual) | *(not in app's catalog — app never offers this)* | `ggml-base.bin` |
| small (multilingual) | *(not in app's catalog — app never offers this)* | `ggml-small.bin` |
| base.en | `base.en.bin` | `ggml-base.en.bin` |
| small.en | `small.en.bin` | `ggml-small.en.bin` |
| large-v3 | `large-v3.bin` | `ggml-large-v3.bin` |
| imported medium.en | `medium.en.bin` (import only accepts `base.en.bin`/`small.en.bin`... see note) | n/a |

Note: `WhisperModelCatalog.importModel`'s allowed filenames are literally `base.en.bin` and
`small.en.bin` only — `medium.en.bin` on disk got there through `downloadModel`, not
`importModel`, despite the UI labeling it "(Imported)" (downloads are registered with the exact
same `.imported` origin/metadata scheme as manual imports — see `WhisperModelCatalog.swift`
`downloadModel`, which reuses `ImportedModelMetadata`). This is pre-existing, intentional, and
not part of BUG-007.

## 8. Does installed recognition require a metadata/sidecar file?

Only for the `.imported` origin (both manually-imported and app-downloaded files). Files placed
directly in `Models/` with a recognized `ggml-<stem>[.en].bin` name are picked up by
`scanInstalledModelFiles()`/`recognizedInstalledModel` **without** any sidecar — origin
`.installed`.

## 9. If a `.bin` exists but metadata is missing, is it safely recognizable?

Yes, by design, provided the filename matches `ggml-<known-stem>[.en].bin` exactly
(`recognizedInstalledModel`). This already works correctly — confirmed by `ggml-base.bin` and
`ggml-small.bin` both loading and running real dictation successfully under ids `"base"`/
`"small"`.

## 10. Why does `medium.en (Imported)` appear installed while other models still appear under Download?

Because it went through the app's own `downloadModel`/import path, which writes a filename that
exactly matches a `downloadableCatalog` id (`medium.en.bin` → id `medium.en`) **and** writes a
metadata sidecar. `ggml-base.bin`/`ggml-small.bin` did not go through that path — their filenames
follow whisper.cpp's own raw `download-ggml-model.sh` convention (`ggml-<stem>.bin`, **no `.en`**
suffix), which `recognizedInstalledModel` correctly parses as the **plain multilingual** `base`/
`small` models — genuinely different files from `base.en`/`small.en`, which have never been
fetched by DexDictate itself. There is no evidence (file dates: `Jun 18`, five days before this
session's BUG-006 work even started; no download-log entries at all for `base.en`/`small.en`)
that these were ever downloaded via the app and "forgot" — they were never the same model to
begin with.

## 11. Are Settings and popover using the same installed/downloadable model rows after BUG-006?

Yes — confirmed by reading `ModelSelectionActions.whisperRows` (shared, single implementation)
and its two call sites (`LiveTranscriptionStatusView` in `QuickSettingsView.swift`,
`DexContextChips` in `DexStateFirstComponents.swift`). Whatever "base"/"small"/`base.en`/
`small.en` display, both surfaces display identically. **Not a Settings/popover divergence.**

## 12. Root cause classification

**UI-honesty gap, not a directory/filename-mapping/sidecar/refresh/download bug.** Specifically:

- Directory: correct (#5, #6).
- Filename→id mapping: correct *for what it's mapping* — `ggml-base.bin` really is the
  multilingual `base` model, and is correctly labeled as such (just as plain `"Base"`, with no
  qualifier distinguishing it from the separately-cataloged `"Base English"`).
- Sidecar/metadata: not required for this recognition path, and not missing anything it needs.
- Catalog refresh: `downloadModel` already calls `refresh()` on success; nothing in this
  session's evidence shows a stale-refresh symptom.
- Failed download: no evidence in logs of any attempted or failed download of `base.en`/
  `small.en`/`large-v3`.

**The actual goblin**: `recognizedInstalledModel`'s display name for a legacy
`ggml-<stem>.bin` file (no `.en`) is just the bare size label (`"Base"`, `"Small"`, `"Tiny"`,
`"Medium"`) — visually near-identical to the catalog's English-only equivalent one row below/
above it (`"Base English (142 MB) — Download"`). A user who has `ggml-base.bin` installed sees
`"Base — Compatibility"` marked installed right next to `"Base English (142 MB) — Download"`
and reasonably reads that as "it thinks I need to download Base again," when in fact these are
two distinct models (multilingual vs. English-only) and the English one genuinely has never
been fetched. This is a real, closeable UI defect — a **display-name ambiguity that makes an
already-installed, unrelated model look like a duplicate of an undownloaded one** — not a
recognition, path, or persistence failure. `large-v3` is unaffected: its catalog id has no `.en`
suffix in the first place, so the legacy scan path and the catalog id already agree exactly.

## Fix scope

Disambiguate the four affected stems (`tiny`, `base`, `small`, `medium` — the ones with a real
`.en` counterpart in `downloadableCatalog`) by giving their non-English recognized display name
an explicit `"(Multilingual)"` qualifier, e.g. `"Base"` → `"Base (Multilingual)"`. This is a
pure display-name change: no id changes, no path changes, no new architecture, and it does not
touch anything for `large`/`large-v1`/`large-v2`/`large-v3` (no ambiguity exists there). See
`BUG_007_MODEL_DOWNLOAD_PERSISTENCE.md` for the applied fix.
