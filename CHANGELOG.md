# Changelog

Spookyfolio is in early development. Entries refer to development Android build numbers, not stable releases. Validation reports distinguish automated checks from on-device checks.

## 0.1.0+28 — 2026-11-22

### Added
- Added read-only transaction detail pages accessible from Activity, account details and holding transactions.
- Added extended transaction information, including account, asset identifiers, comments and converted monetary values.
- Added remote asset lookup and a temporary asset filter in the main Activity section.
- Combined asset filtering with the global account filter.
- Preserved Activity state when opening transaction details and reset temporary asset filters when leaving Activity or changing accounts.
- Updated the application description to "Alternative native mobile client for Ghostfolio."

### Validation
- Flutter analysis completed without issues.
- All 141 automated tests passed.
- Android debug APK compiled successfully.
- Transaction details, asset filtering, account filtering and navigation verified on an Android device.

## 0.1.0+27 — 2026-11-22

### Added
- Added a read-only account detail screen with Overview, Balances and Activity sections.
- Added account balance history with recorded dates, values and optional comments.
- Added account-specific financial activities with lazy loading and pagination.
- Added native swipe navigation between account detail sections.
- Added account detail and balance REST endpoints with response validation.

### Fixed
- Preserved the current navigation destination when changing the global account filter.
- Preserved contextual navigation during portfolio refresh, API errors and retries.
- Prevented stale portfolio snapshots from being reused across server or session changes.

### Validation
- Flutter analysis completed without issues.
- All 101 automated tests passed.
- Account detail navigation, balances, activity and account filtering verified on Android.

## 0.1.0+26 — 2026-11-22

### Changed
- Added native horizontal swipe navigation across Overview, Portfolio, Activity and More.
- Added swipe navigation within Holdings / Accounts and Settings / About.
- Unified hierarchical navigation without duplicate contextual routes or screen transitions.
- Restored the originating main destination when leaving Portfolio or More with Android Back.
- Preserved Activity pagination and cached data across navigation.
- Kept the interactive performance chart's horizontal gestures independent of page navigation.

### Validation
- Flutter navigation, gesture, chart and Activity pagination regression tests passed.
- Flutter analysis completed without issues; all 82 automated tests passed.
- Final navigation behavior confirmed on an Android device.

## 0.1.0+25 — 2026-11-22

### Changed
- Replaced the three holding-analysis metric cards with one compact summary strip.
- Added a responsive stacked layout for narrow displays and enlarged text.
- Preserved server-provided value, allocation and return figures.

### Validation
- Flutter analysis completed without issues.
- All 75 automated tests passed.
- Compact summary layout visually approved during Android testing.

## 0.1.0+24 — 2026-11-21

### Changed
- Reorganized mobile navigation into Overview, Portfolio, Activity and More.
- Introduced contextual bottom navigation for Holdings / Accounts and Settings / About.
- Added hierarchical back navigation to return to the main destinations.
- Made Accounts a read-only overview, retaining account filtering in the global AppBar.
- Added a refresh action for account information.
- Added an About screen with theme-aware branding, app version, repository and license.
- Shortened the application title to display version and build number.

### Validation
- Flutter analysis completed without issues.
- All 73 automated tests passed.
- Navigation and account views verified on an Android device.
- The final abbreviated title still requires verification on the device.

## 0.1.0+23 — 2026-11-21

### Changed
- Made the native Android splash icon theme-aware: distinct light and dark assets, with the dark logo retained.
- Preserved the native Android splash; no secondary branded Flutter startup screen is shown.

### Validation
- Light and dark splash appearance confirmed on an Android device.
- The Android app was checked on a device after the build 23 consolidation.
- The baseline source tree was validated by GitHub Flutter CI (analyze and tests) at infrastructure commit `2d2a194`, which adds only `LICENSE` and the CI workflow to the application baseline `95582ce`. This does not constitute an Android release qualification.

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
