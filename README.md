# Spookyfolio

Spookyfolio is a native Flutter mobile client for [Ghostfolio](https://github.com/ghostfolio/ghostfolio), designed to connect directly to the REST API rather than embed the web interface.

The current client connects to Ghostfolio Cloud and self-hosted Ghostfolio through the existing REST integration. Ghostfolio-NG-specific extensions are future work; the next functional phase will use only information and REST capabilities available in standard Ghostfolio.

> **Status:** development build `0.1.0+29`. This is an early development preview, not a stable, production-qualified or security-audited release.

## Implemented features

- Server selection, connectivity inspection, authentication and securely persisted credentials, including Ghostfolio Cloud signup.
- Dashboard Overview with server-reported portfolio values, selectable performance ranges and an interactive return chart.
- Holdings with an allocation chart and read-only holding details and transactions.
- Accounts overview and account details with Overview, Balances and Activity subsections.
- Paginated Activity with read-only transaction details, remote asset lookup and a temporary asset filter.
- Shared account selection and server-side filtering for portfolio values, performance and Activity.
- System, light and dark appearance preferences, an About page and theme-aware native Android splash branding.

Financial values and the displayed performance calculation method come from Ghostfolio; unavailable values are not replaced with invented zeros. Holding details are portfolio-wide and are disabled while an account filter is active.

A dedicated Allocations screen, Invested vs Earned, advanced ROI / ROAI / PnL analysis and Ghostfolio-NG-specific functionality are not implemented. See the [Roadmap](docs/roadmap.md) for priorities.

## Current navigation

The AppBar retains the application version title. Its **three-dot dropdown menu** selects the main section, highlights the current section and includes **Refresh**.

| Main section | Subsections |
|---|---|
| Dashboard | Overview |
| Portfolio | Holdings, Accounts, Activity |
| Settings | Preferences, About |

A bottom Material 3 `NavigationBar` shows icons and labels for the active section's subsections. Dashboard has no redundant single-item bottom navigation. Horizontal swipes switch subsections and keep the bar selection synchronized. Android Back returns from detail pages, closes an open section menu, or restores the previous section with its remembered subsection.

Navigation preserves the selected account, performance range and loaded Activity pages. Refresh reloads portfolio data on Overview or Holdings, accounts on Accounts, and the feed on Activity; it is disabled in Settings.

## Development prerequisites

- Flutter SDK compatible with the constraints in `pubspec.yaml`.
- Android SDK and a configured Android toolchain for Android builds.
- Xcode on macOS for iOS builds (iOS has not been qualified as part of the Android development milestones).

## Build and test

```bash
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter build apk --debug
```

For an Android device connected over ADB:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Build outputs and local SDK paths are not committed. Android builds use the Gradle Wrapper checked into `android/`.

## Configuration and security

Spookyfolio uses the configured Ghostfolio server URL and its authentication endpoints. Do not commit security tokens, API keys, local environment files, signing keys, or personal portfolio data. Before reporting a bug, redact server addresses and financial data when needed.

## Documentation

- [Changelog](CHANGELOG.md): development builds and their validation status.
- [Architecture](docs/architecture.md): API, session, filtering and data ownership.
- [Roadmap](docs/roadmap.md): implemented navigation, agreed priorities and future work.

## Relationship to Ghostfolio

Spookyfolio is a separate mobile client project, not an official Ghostfolio application. Ghostfolio and its trademarks belong to their respective owners.

## License

Spookyfolio is licensed under the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0). It is an independent project and is not affiliated with or endorsed by the Ghostfolio maintainers.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.
