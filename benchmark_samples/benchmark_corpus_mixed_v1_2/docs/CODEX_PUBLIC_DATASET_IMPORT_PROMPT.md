# Codex Prompt: Public Dataset Import for DexDictate Benchmark Corpus

Paste this into Codex from the DexDictate repository root.

```text
You are working in the DexDictate macOS repository at:
/Users/andrew/DexDictate_MacOS.nosync

Goal:
Expand the existing benchmark corpus package with public transcripted speech clips. Do the downloading/import work that Andrew does not want to manually babysit. Keep production DexDictate untouched.

Corpus path:
benchmark_corpus_mixed_v1_2

Hard restrictions:
- Do not modify production DexDictate source code.
- Do not modify output insertion, clipboard, Accessibility, secure-field, focus-matching, permissions, audio route recovery, signing, release, plist, entitlements, or build packaging code.
- Do not commit unless explicitly asked.
- Do not use random YouTube/video/audio sources.
- Do not add clips without exact expected transcripts.
- Do not make synthetic clips part of the default scoring manifest.
- Do not claim public data was imported unless the files and manifest validate.

First inspect:
- benchmark_corpus_mixed_v1_2/README.md
- benchmark_corpus_mixed_v1_2/docs/PUBLIC_DATASET_IMPORT_GUIDE.md
- benchmark_corpus_mixed_v1_2/docs/QA_REPORT.md
- benchmark_corpus_mixed_v1_2/source_licenses.md
- benchmark_corpus_mixed_v1_2/tools/build_public_augmented_corpus.sh
- benchmark_corpus_mixed_v1_2/tools/fetch_public_datasets.sh
- benchmark_corpus_mixed_v1_2/tools/import_librispeech_archive.py
- benchmark_corpus_mixed_v1_2/tools/import_openslr83_archive.py
- benchmark_corpus_mixed_v1_2/tools/validate_corpus.py

Then run a dry run:
cd /Users/andrew/DexDictate_MacOS.nosync/benchmark_corpus_mixed_v1_2
bash tools/build_public_augmented_corpus.sh --download --max-librispeech 15 --max-slr83 10 --dry-run

If the dry run looks sane, run:
bash tools/build_public_augmented_corpus.sh --download --max-librispeech 15 --max-slr83 10

Only include Speech Commands if disk space is clearly sufficient and you explicitly decide it is worth the 2.37 GiB download / 8.17 GiB extracted footprint:
bash tools/build_public_augmented_corpus.sh --download --include-speech-commands --max-librispeech 15 --max-slr83 10 --max-speech-commands 10

After import, validate:
python3 tools/validate_corpus.py .
python3 tools/select_manifest.py --list
python3 - <<'PY'
import json
from collections import Counter
from pathlib import Path
root=Path('.')
data=json.loads((root/'transcripts.json').read_text())
print('active clips', len(data))
print(Counter(item.get('category') for item in data))
for item in data[:5]: print(item['file'], '=>', item['expected'][:80])
PY

Then from the DexDictate repo root, run the existing matrix if feasible:
cd /Users/andrew/DexDictate_MacOS.nosync
./scripts/benchmark_speech_matrix.sh --corpus-dir benchmark_corpus_mixed_v1_2

Report back:
- exact commands run
- public archives downloaded
- clips imported per source
- active transcripts.json clip count
- validation output
- benchmark output if run
- any failures or skipped sources
- current git status

Do not commit unless Andrew asks.
```
