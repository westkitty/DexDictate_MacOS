# Reflection — 2026-08-01

## Outcome So Far

Every original non-main branch tip is protected by a pushed annotated archive
tag and is an ancestor of the integration branch. Current-safe code was merged,
missing spoken punctuation was ported, historical UI recovery material was
archived, standalone React and Remotion work was isolated, and superseded code
was retained without replacing newer mainline implementations.

## Compatibility and Drift

- Current permission, insertion, model, settings, and experiment boundaries remain authoritative.
- Full/onset silence trimming remains disabled because its current owner documents sentence-onset clipping risk.
- Custom `Dex` commands still precede spoken punctuation processing.
- Production Swift package roots were not overlaid by either standalone Node.js project.
- Version 1.8.0 remains current; the v1.5 tree was not restored.
- Project Sentinel's concurrent `.resurrection` rewrites remain unstaged and excluded.

Verification exposed one unplanned defect in `build.sh`: a custom `INSTALL_DIR`
was incorrectly treated as the user-install alternative, causing the canonical
system app to be removed before verification failed. The application was
immediately restored through a successful standard system install. Commit
`80677ea` now makes custom targets preserve both canonical installations and
adds a regression scenario. The 21-scenario install-safety suite passes, and a
fresh custom-target build now verifies without disturbing `/Applications`.

## Verification Evidence

- Full `swift test`: 507 tests, 3 skipped, 0 failures.
- Focused `CommandProcessorTests`: 13 tests, 0 failures.
- `swift build`: passed.
- Signed production package build: passed.
- Custom-target package build after the safety fix: passed and preserved canonical installs.
- Standard system install: exactly one canonical app at `/Applications/DexDictate.app`, version 1.8.0, valid deep signature, running from the expected executable.
- Installed-app release validation: 0 failures; warnings are limited to Gatekeeper assessment and absent release archives/checksums.
- SwiftLint strict gate: passed, including deliberate-violation detection and baseline restoration.
- Build/install safety suite: 21 passed, 0 failed.
- UX prototype: frozen install, production build, and lint passed.
- Remotion explainer: clean install, 0 audit vulnerabilities, and `MainComposition` enumerated at 30 fps, 1920x1080, 1574 frames.
- Complete committed diff check: clean.
- Changed-path secret/private-key pattern scan: no matches.
- Only changed object over 5 MB: the reviewed 8.9 MB UI screenshot packet ZIP; its 64 entries are bounded to screenshots, a manifest, and readme.
- All seven original branch tips are ancestors of the integration branch.

## Residual Proof

- Exercise reversible dictation undo manually in representative target applications for exact restore, verified trailing trim, refusal after content/focus change, and best-effort Backspace fallback.
- Pull-request continuous integration and remote-main parity remain publication gates.
- Branch deletion remains blocked until remote `main` contains the integration tip and every archive tag is reverified.

## Decision

Continue to publication. No reviewed legacy capability remains without either a
current implementation, a maintained artifact location, or explicit recoverable
ancestry.
