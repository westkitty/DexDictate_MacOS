# DexDictate Remotion Explainer

This standalone Remotion project was recovered from branch
`codex/remotion-runner-20260314-225455` at commit
`1bfd3336a5f91493a9ee348b14e4954e0ec018ea` during the 2026-08-01 branch
integration.

It is isolated beneath `marketing/` so its Node.js dependencies and root names
cannot interfere with the production Swift package. The original branch's
`.claude` and `.codex` skill symlinks were intentionally not copied. Its
Remotion reference material is retained locally under `reference/`.

## Verify

```sh
npm ci
npm run remotion:compositions
```

Use `npm run remotion:studio` for interactive editing. The production macOS
application does not depend on this project. Composition verification uses
local port `43123`; choose another explicit port if that one is occupied.
