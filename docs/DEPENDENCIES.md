# Dependencies

DexDictate is local-first and keeps its dependency surface deliberately small.

## Swift package dependencies

### SwiftWhisper — pinned to a specific revision
`Package.swift` pins SwiftWhisper to an exact commit:

```
.package(url: "https://github.com/exPHAT/SwiftWhisper.git",
         revision: "deb1cb6a27256c7b01f5d3d2e7dc1dcc330b5d01")
```

**Why a revision, not a version range:** SwiftWhisper's `master` documents very slow
Debug builds. The pinned revision forces the optimized (`-O3`) build path so local
dictation latency stays usable during development. A floating version could silently
regress build performance, so the pin is intentional — do not loosen it casually.

**`Package.resolved` is committed** and CI fails if `swift package resolve` would change
it (so the locked graph is reproducible across machines and CI).

### Updating the pin
1. Pick the new SwiftWhisper commit and confirm it still builds with optimization.
2. Update the `revision:` in `Package.swift`, run `swift package resolve`, and commit the
   updated `Package.resolved`.
3. Run `make check` and `./build.sh --release` locally; verify dictation latency is unchanged.
4. Note the change in `docs/DEXDICTATE_BIBLE.md`.

## Model assets
The Whisper model (`tiny.en.bin`) is fetched by `scripts/fetch_model.sh`, not vendored in
git. CI caches it by content key. It is bundled into the app at build time.

## Web prototype
`dexdictate-ux/` (a Vite/React design prototype) is not part of the shipping app and its
`node_modules/` is gitignored. It can be moved to a separate repository if it is kept.
