# Spookyfolio

Spookyfolio is a native Flutter mobile client for [Ghostfolio](https://github.com/ghostfolio/ghostfolio), designed to connect directly to the REST API rather than embed the web interface.

The app is being developed for Ghostfolio Cloud, self-hosted Ghostfolio, and Ghostfolio-NG. Server-specific features must be enabled according to capabilities actually available from the connected backend.

> **Status:** early development preview (`0.1.0+23`). The codebase is not yet presented as a production-ready or security-audited release. The repository is public and licensed under AGPL-3.0; no production-signed mobile release is available yet.

## Implemented features

- Server selection and connectivity inspection.
- Authentication and locally persisted session, including Ghostfolio Cloud signup.
- Portfolio overview, historical performance and interactive return chart.
- User-selected performance calculation method as reported by Ghostfolio (including ROI or ROAI where supported).
- Holdings, asset allocation and detailed holding analysis.
- Paginated activity feed and holding-specific transactions.
- Account overview, account selection and server-side filtering across the main financial views.
- System, light and dark appearance modes, and native Android splash branding adapted to the system's light/dark appearance.

Financial values and performance are retrieved from Ghostfolio. The client does not substitute missing or restricted monetary values with invented zeros. Holdings detail may present global figures when the backend does not support account-specific filtering; the filtered view must not misrepresent those figures.

## Current navigation

The mobile interface has four main destinations: **Overview**, **Portfolio**, **Activity**, and **More**. Portfolio provides contextual navigation between Holdings and Accounts; More provides Settings and About. The Android back action returns from contextual navigation to the main destinations. See [Roadmap](docs/roadmap.md).

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
- [Roadmap](docs/roadmap.md): proposed navigation and next milestones.

## Relationship to Ghostfolio

Spookyfolio is a separate mobile client project, not an official Ghostfolio application. Ghostfolio and its trademarks belong to their respective owners.

## License

Spookyfolio is licensed under the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0). It is an independent project and is not affiliated with or endorsed by the Ghostfolio maintainers.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.
