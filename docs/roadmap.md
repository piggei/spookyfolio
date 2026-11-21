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

## Near-term work

- Qualify the first Git baseline and documentation; inspect all staged files, including native Gradle wrapper assets.
- Remove unused build 19 Flutter startup components only after verifying local contents and references.
- Resolve remaining non-blocking analyzer suggestions.
- Add dedicated route structure for the agreed navigation model when introducing new sections.
- Expand account and cash workflows without misleading currency aggregation.
- Analyze advanced indicators and NG-specific functionality before implementing M10.
- Introduce GitHub Actions CI for analysis and tests, followed by separately qualified artifact builds. Do not auto-publish from unqualified builds.

## Release process

Until qualified, build numbers identify development snapshots rather than stable releases. Commit, tag, compiled artifact and recorded verification results should be traceable to the same source. No public release or automatic publication is implied by tagging development code.
