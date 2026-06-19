# Speech Engine Exploration Results Template

Date:
Machine:
Commit:
Build command:
Corpus:
Microphone/input source:
Notes:

## Scope Confirmation

- Production dictation path changed: no
- Output insertion changed: no
- Secure-field behavior changed: no
- Audio route recovery changed: no
- Packaging/signing changed: no
- Network speech path introduced: no

## Baseline

Command:

```bash
./scripts/benchmark.sh --corpus-dir sample_corpus --model tiny.en --decode-profile accuracy --build release
```

| Engine | Model | Decode Profile | Files | Avg WER | Avg Latency ms | p95 Latency ms | Notes |
|---|---|---|---:|---:|---:|---:|---|
| SwiftWhisper | tiny.en | accuracy |  |  |  |  |  |

## Candidate Matrix

| Engine | Model | Command | Files | Avg WER | Avg Latency ms | p95 Latency ms | Exit Code | Result Path |
|---|---|---|---:|---:|---:|---:|---:|---|
| SwiftWhisper | tiny.en |  |  |  |  |  |  |  |
| SwiftWhisper | base/base.en |  |  |  |  |  |  |  |
| SwiftWhisper | small/small.en |  |  |  |  |  |  |  |
| MLX-Audio |  |  |  |  |  |  |  |  |

## Quality Checks

| Engine | Model | Punctuation Issue Count | Command Issue Count | Clipping Proxy Failures | Notes |
|---|---|---:|---:|---:|---|
| SwiftWhisper | tiny.en |  |  |  |  |
| MLX-Audio |  |  |  |  |  |

## Failure Modes

| Engine | Model | Failure | Repro Command | Impact | Follow-up |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

## Interpretation

Decision:

- Keep SwiftWhisper production path:
- Continue MLX-Audio benchmark-only:
- Stop MLX-Audio exploration:

Reasoning:

## Next Smallest Safe Step

Pick exactly one:

- Expand corpus before more engine work.
- Add a test-only speech engine adapter boundary.
- Run MLX-Audio as an explicit sidecar benchmark command.
- Stop and harden existing SwiftWhisper metrics instead.

