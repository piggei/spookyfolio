# Roadmap

This is a design direction, not a claim that the listed features already exist.

## Navigation proposal

```text
Overview
  Dashboard, historical returns and performance

Portfolio
  Holdings
    Asset detail
  Accounts
    Account detail
    Cash balance
    Cash movements (only when supported by the server)

Activity
  Transactions
  Transaction detail

More
  Advanced analyses (when implemented)
    ROI / ROAI / PnL
    Benchmarks
  Settings
    Appearance
    Server and session
  About
```

The bottom navigation should retain four destinations: Overview, Portfolio, Activity and More. Secondary routes should be introduced only when their backing features exist. Ghostfolio-NG-specific capabilities should be discovered from supported API behavior, not a hardcoded brand string.

## Completed foundations

- Created and published the initial Git baseline `95582ce`, tagged `v0.1.0-dev.23`.
- Removed the unused build 19 Flutter startup component and resolved analyzer suggestions.
- Introduced the initial Flutter analysis and test CI; its first run passed on `2d2a194`.
- Added development documentation and AGPL-3.0 licensing.

## Near-term work

- Add dedicated route structure for the agreed navigation model when introducing new sections.
- Expand account and cash workflows without misleading currency aggregation.
- Analyze advanced indicators and NG-specific functionality before implementing M10.
- Qualify an Android release variant, including manifest permissions and secure production signing, before distributing signed artifacts.
- Introduce artifact-build workflows separately from CI and do not auto-publish unqualified builds.

## Release process

Until qualified, build numbers identify development snapshots rather than stable releases. Commit, tag, compiled artifact and recorded verification results should be traceable to the same source. No public release or automatic publication is implied by tagging development code.
