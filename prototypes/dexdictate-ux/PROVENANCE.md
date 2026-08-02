# DexDictate UX Prototype Provenance

This standalone React prototype was recovered from branch
`feat/audio-import-custom-commands-per-app-insertion` at commit
`7701b6ff10ee8d6f1784d72aa007667ca6b56c52` during the 2026-08-01 branch
integration.

It is retained for design reference and experimentation. It is not wired into
the production Swift package, macOS application build, or release pipeline.
The production audio-import, custom-command, and per-application insertion
features already have newer mainline implementations; those legacy Swift
files were therefore preserved through Git ancestry rather than overlaid here.

Use `pnpm install --frozen-lockfile`, then `pnpm build`, from this directory to
verify the prototype independently.
