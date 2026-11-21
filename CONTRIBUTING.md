# Contributing to Spookyfolio

Thank you for considering a contribution. Spookyfolio is an independent Flutter
mobile client for Ghostfolio, Ghostfolio Cloud, self-hosted deployments and
Ghostfolio-NG.

## Before contributing

- Search existing Issues and Discussions before creating duplicates.
- Use Discussions for open-ended ideas and questions; use Issues for actionable,
  reproducible bugs and sufficiently scoped enhancements.
- Never attach real access tokens, authentication responses, signing keys,
  private server addresses or personal financial records to reports.
- For security vulnerabilities, avoid posting exploit details in public Issues;
  contact the maintainer privately before public disclosure.

## Development workflow

1. Branch from the current `main` branch. Keep each change focused.
2. Keep financial calculations and server-owned data semantics unchanged unless
   the change explicitly calls for them and has regression coverage.
3. Do not assume Ghostfolio-NG capabilities exist on upstream Ghostfolio or
   Ghostfolio Cloud. Handle absent and restricted data explicitly.
4. Run the validation commands below before proposing a pull request.
5. Open a pull request against `main` describing the behavior, tests, API
   compatibility implications, and any user-visible changes.

```bash
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

For Android-specific changes, also build and verify on a real device when
possible. A passing Flutter CI does not qualify release signing or the Android
runtime. Android and iOS builds are separate validation targets.

## Scope and releases

The repository currently ships development milestones, not a stable public
mobile release. Do not add automated publishing or change signing practices
without prior review. Release builds require a production signing configuration
and dedicated qualification.

## License

Contributions are submitted under the repository's GNU Affero General Public
License v3.0 (AGPL-3.0). See [LICENSE](LICENSE).
