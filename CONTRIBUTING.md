# Contributing

Bug reports and pull requests are welcome.

## Project status

DexDictate is published as-is. The repository is still buildable and documented, but active roadmap work has concluded and there is no guarantee that proposed changes will be reviewed or merged.

If you need a guaranteed path for new features or long-term maintenance, plan to fork the repository and maintain your own branch.

## Before opening a pull request

Run the checks that match the scope of your change:

```bash
swift test
swift run VerificationRunner
./build.sh
```

If you touched release packaging or bundle assembly, also run:

```bash
./scripts/validate_release.sh
```

## Expectations for changes

- Keep README and public-facing docs accurate to the repository contents.
- Do not add claims about features, platforms, or workflows that the codebase does not support.
- Prefer small, reviewable changes over broad speculative rewrites.
- Preserve the current macOS 14+ and Apple Silicon scope unless you are intentionally reworking the build and runtime constraints.
