# Roadmap

This roadmap separates implemented functionality from agreed development priorities and exploratory future work. It does not assign implementation dates or promise backend capabilities.

## Implemented navigation — build 0.1.0+29

```text
Dashboard
  Overview

Portfolio
  Holdings
  Accounts
  Activity

Settings
  Preferences
  About
```

The AppBar three-dot dropdown selects the main section and includes Refresh. A bottom Material 3 NavigationBar displays the active section's subsections with icons and labels. Dashboard has no redundant single-item bottom navigation. Horizontal swipes switch subsections, and Android Back restores previous sections and remembered subsections or returns from detail pages.

The foundations include server connectivity and authentication, shared portfolio data, an interactive return chart, holdings with an allocation chart, account details and balance history, paginated Activity, transaction details, account and temporary asset filters, appearance preferences and About. An allocation chart within Holdings is not a dedicated Allocations screen. See the [README](../README.md) for the current feature summary and [Architecture](architecture.md) for navigation and state ownership.

## Agreed next functional priority: Dashboard Enhancement

| Dashboard subsection | Status |
|---|---|
| Overview | Implemented |
| Allocations | Planned |
| Invested vs Earned | Planned |

Initially, Dashboard Enhancement must use only information and REST capabilities available in **standard Ghostfolio**. Review the available data and semantics before implementing either planned subsection; this roadmap does not claim that a specific endpoint or required metric already exists. Preserve server-owned financial calculations, currency distinctions and explicit unavailable values.

Ghostfolio-NG extensions will be evaluated and introduced in a later phase. They are not a prerequisite for the initial Dashboard Enhancement work. Planned subsections must not appear as empty navigation destinations before their functionality is implemented.

## Subsequent development directions

After the Dashboard Enhancement priority, further work should include the following areas. Their detailed scope and ordering remain to be defined:

- Advanced ROI / ROAI / PnL analysis, beyond displaying returns and the calculation method reported by the server.
- Ghostfolio-NG-specific capabilities, following evaluation of supported API behavior and compatibility with standard Ghostfolio.
- Cash Management, beyond the existing read-only account cash figures and recorded balance history.
- Further financial and allocation analysis beyond the initial Dashboard Enhancement scope.

These are future development directions, not implemented features or committed delivery milestones. Specific indicators, comparisons and workflows within them remain exploratory until their data requirements, financial semantics and backend support have been reviewed.

## Release qualification

Build numbers identify development snapshots rather than stable releases. Automated checks and Android device verification are recorded separately in the [Changelog](../CHANGELOG.md); they do not establish production qualification. Release signing, distribution and any artifact-publication workflow require separate review and qualification. No public release or automatic publication is implied by a development build number.
