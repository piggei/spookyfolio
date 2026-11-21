# Architecture

## Scope

Spookyfolio is a Flutter client that talks directly to Ghostfolio REST endpoints. It does not embed the Ghostfolio web UI and does not calculate financial performance independently of the server.

## Main responsibilities

- **Startup and session:** server selection, authentication, local session restoration and theme preference.
- **REST client:** authenticated requests, constrained response sizes and timeouts, DTO parsing and explicit errors.
- **Mobile shell:** main destinations, shared portfolio snapshot, selected date range and current account filter.
- **Activity feed:** lazy paginated loading; stale result protection when requests or filters change.
- **Holdings:** positions and allocations from server-provided portfolio data; asset detail and transactions.
- **Accounts:** list and aggregate figures from Ghostfolio, including per-account currency distinctions.

## Relevant Ghostfolio REST endpoints

| Purpose | Request |
|---|---|
| User profile | `GET /api/v1/user` |
| Accounts | `GET /api/v1/accounts` |
| Account details | `GET /api/v1/accounts/:id` |
| Portfolio details | `GET /api/v1/portfolio/details` |
| Performance | `GET /api/v2/portfolio/performance` |
| Activity | `GET /api/v1/activities` |
| Holding detail | `GET /api/v1/portfolio/holding/:dataSource/:symbol` |

Relevant portfolio and activity endpoints accept the `accounts` query parameter for server-side filtering. The holding detail endpoint has no corresponding account filter: the UI must distinguish global from account-specific data instead of silently presenting global metrics as filtered metrics.

## Financial data invariants

1. Delegate ROI, ROAI, performance, currency effects and historical values to the server.
2. Preserve absent/restricted numbers as unavailable, not zero.
3. Distinguish account cash in its own currency from holdings value in the portfolio base currency; never sum unlike currencies without a documented conversion.
4. Apply account filters at the server when possible, so allocation, performance and totals remain coherent.
5. Reset pagination and reject stale responses after an account/session change.

## Native resources

Android has its own startup splash, selected before Flutter initialization. A separate icon resource is provided for system light and dark themes. The user-selected Flutter theme is not synchronized to the native startup mechanism; native selection follows the Android system appearance.

## Verification

Use `flutter analyze`, sequential `flutter test --concurrency=1`, then a device build and functional tests. A passing unit/widget suite does not prove Android lifecycle, authentication or financial API behavior on a device.
