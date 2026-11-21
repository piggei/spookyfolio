# Changelog

Spookyfolio is in early development. Entries refer to development Android build numbers, not stable releases. Validation reports distinguish automated checks from on-device checks.

## 0.1.0+23 — 2026-11-21

### Changed
- Made the native Android splash icon theme-aware: distinct light and dark assets, with the dark logo retained.
- Preserved the native Android splash; no secondary branded Flutter startup screen is shown.

### Validation
- Light and dark splash appearance confirmed on an Android device.
- Full automated verification of the final build 23 tree is still required before tagging the baseline.

## 0.1.0+22 — 2026-11-21

### Added
- Account overview: account name and platform, original account currency and cash balance, base-currency holdings value, allocation, activity count and dividends where available.
- Account selection from the account overview.

### Validation
- 73 Flutter tests passed on the development machine following the build 22 changes.
- Account overview inspected on an Android device.
- `flutter analyze` reported six informational suggestions, including two in an unused legacy startup component.

## 0.1.0+21 — 2026-11-21

### Added
- Server-side account filtering for portfolio details, performance and activity.
- Shared account selection across financial screens and pagination reset on account change.

### Validation
- Multiple-account filtering confirmed on a device.
- Display of the ROI method set on the Ghostfolio server confirmed.

## 0.1.0+20

### Changed
- Removed the secondary branded Flutter splash from the active startup flow.
- Added a dedicated Android splash icon sized to respect Android 12+ circular masking.

## 0.1.0+19 — experimental, superseded

- Trial of a branded Flutter startup screen; subsequently replaced by the native-only design.

## 0.1.0+18

- Moved holding detail tabs to the bottom and customized the native Android splash.

## 0.1.0+17

- Refined holding performance colors, Analysis content layout and Asset presentation.

## Earlier development

The first development increments established server connectivity, authentication, portfolio overview, historical performance, interactive charts, holdings, account-independent asset details, paginated transactions and theme support. Exact per-build history remains to be reconstructed from verified artifacts.
