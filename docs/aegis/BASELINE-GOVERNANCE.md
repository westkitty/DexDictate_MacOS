# Baseline Governance

The current remote `main` branch is the source baseline for integration work. Legacy branches are evidence and candidate capability sources, not automatic owners of current behavior.

An integration slice may change the current tree only when it:

1. preserves an artifact that has no current home;
2. restores a user capability absent from current `main`; or
3. records historical ancestry without replacing newer implementations.

Current permission, output-safety, model-selection, settings-migration, and default-off experimental boundaries remain authoritative unless separately approved and verified.

Generated `.resurrection` snapshots are checkout-local recovery state and are never adopted from a legacy branch during this integration.
