# Architecture

## Scope

Spookyfolio is a Flutter client that talks directly to Ghostfolio REST endpoints. It does not embed the Ghostfolio web UI or calculate financial performance independently of the server. The navigation described here is implemented in development build `0.1.0+29`.

## Main responsibilities

- **Startup and session:** server selection, authentication, credential storage, session restoration and theme preference.
- **REST client:** authenticated requests, constrained response sizes and timeouts, DTO parsing and explicit errors.
- **Mobile shell:** section navigation, shared portfolio snapshot, selected performance range and account filter.
- **Activity feed:** lazy paginated loading, transaction details and temporary asset filtering; stale result protection after account or session changes.
- **Holdings:** positions and an allocation chart from server-provided portfolio data; holding details and transactions.
- **Accounts:** catalog and read-only details, recorded balance history and account-specific Activity, preserving currency distinctions.

## Navigation

[lib/mobile_shell.dart](../lib/mobile_shell.dart) defines two levels:

| Main section | Subsections |
|---|---|
| Dashboard | Overview |
| Portfolio | Holdings, Accounts, Activity |
| Settings | Preferences, About |

The AppBar uses `AppVersionTitle` as its title and a compact `Icons.more_vert` IconButton to open a Material 3 `MenuAnchor`. The menu lists the three main sections, highlights the selected section and offers Refresh. Each section with multiple destinations has a bottom `NavigationBar` with icons and labels. Dashboard renders Overview directly, without a single-item bar. There is no top TabBar or swipe between main sections.

### Definitions and state

- **`_Section` and `_Destination`** declare section membership, labels and icons. The shell's `pageBuilder` switch registers the existing page widgets. New destinations need localized configuration, page registration and an explicit Refresh policy; the general navigation machinery remains unchanged.
- **`_ShellNavigation`** owns the selected main section, a remembered subsection index per section and a stack of previous sections. Account selection and performance range are separate shell state, not navigation state.
- **`IndexedStack`** holds the section containers and displays only the selected section. Its session-specific key allows retained section state to be discarded when the server or JWT changes.
- **`_SectionPages`** renders a section's destinations. For multiple destinations, it places a `TabBarView` above a bottom `NavigationBar`; for one destination it renders the page directly. It does not load portfolio data.
- **`TabController` and `TabBarView`** coordinate subsection transitions. Each section container owns and disposes its controller. Bottom-bar taps animate the controller; controller changes report the subsection index to `_ShellNavigation`, keeping swipe gestures and the selected bottom-bar item synchronized.
- **`_RetainedPage`** defers building a destination's page until its first activation. Its visited flag is initialized in `initState()` and updated in `didUpdateWidget()`. `AutomaticKeepAliveClientMixin` retains visited pages inside the subsection view; `build()` reads the flag without changing it.

### History and Android Back

Changing to a different section pushes the previous section onto history, except that explicitly selecting Dashboard clears history. Selecting the current section is a no-op. Subsection changes update that section's remembered index without adding history entries.

The shell's `PopScope` closes an open main menu first. Otherwise, when section history exists, Android Back restores its last entry and that section's latest remembered subsection. Repeated section visits can create repeated history entries; subsection selections are remembered per section rather than copied into each history entry. With no menu or section history, the shell allows the route's normal Back handling.

Holding Detail, Account Detail and transaction details remain separate Navigator routes. Back returns to the retained shell underneath. Holding Detail keeps its Analysis, Asset and Activity tabs; Account Detail keeps Overview, Balances and Activity. Their internal navigation is separate from `_ShellNavigation`.

## Data lifetime, filtering and Refresh

The shell loads one shared portfolio snapshot containing profile, details and history. Section and subsection selection do not refresh it. Accounts and Activity mount lazily when first selected; visited pages stay mounted, preserving loaded account data, Activity pagination and page state. Navigation also preserves the selected account and performance range.

The account selector is independent of navigation. Changing the account or performance range refreshes the relevant portfolio snapshot without dismantling the section containers. Activity resets pagination when its account changes. Its temporary asset filter can be combined with the account filter, but is cleared when leaving Activity or changing the account or session; ordinary unfiltered pagination survives navigation. See [lib/activity_feed.dart](../lib/activity_feed.dart).

Refresh dispatches according to the active destination:

| Destination | Refresh behavior |
|---|---|
| Overview or Holdings | Reload the shared profile, portfolio details and performance history |
| Accounts | Increment the embedded Accounts page's refresh revision to reload its catalog |
| Activity | Refresh the retained feed using its current filters |
| Preferences or About | Refresh is disabled |

The snapshot view retains existing page containers during subsequent loading, errors and retries. A server or JWT change resets navigation, account selection, performance range, catalog cache and snapshot state, rebuilds the session-keyed page tree and closes old detail routes and account sheets. Each snapshot request captures its server, JWT, account and range before awaiting, and a session-keyed `FutureBuilder` prevents old results from replacing the new session's data.

## Relevant Ghostfolio REST endpoints

These are requests made by [lib/portfolio_client.dart](../lib/portfolio_client.dart); availability and returned fields depend on the connected server and permissions.

| Purpose | Request |
|---|---|
| User profile | `GET /api/v1/user` |
| Accounts | `GET /api/v1/accounts` |
| Account details | `GET /api/v1/accounts/:id` |
| Account balance history | `GET /api/v1/accounts/:id/balances` |
| Portfolio details | `GET /api/v1/portfolio/details` |
| Performance | `GET /api/v2/portfolio/performance` |
| Activity | `GET /api/v1/activities` |
| Transaction details | `GET /api/v1/activities/:id` |
| Asset lookup | `GET /api/v1/symbols/lookup` |
| Holding detail | `GET /api/v1/portfolio/holding/:dataSource/:symbol` |

The client uses the `accounts` query parameter for portfolio details, performance and Activity filtering. Holding details are portfolio-wide; the Holdings page disables entry to them when an account filter is active rather than displaying global metrics as account-specific metrics. The Accounts catalog itself is not narrowed by the global account filter.

## Financial data invariants

1. Display server-provided performance values and calculation method; do not calculate ROI, ROAI or PnL independently in the client. Dedicated advanced analysis screens are future work.
2. Preserve absent or restricted numbers as unavailable, not zero.
3. Distinguish account cash in its own currency from holdings value in the portfolio base currency; never sum unlike currencies without a documented conversion.
4. Use server-side account filtering for portfolio details, performance and Activity.
5. Reset Activity pagination and reject stale responses after an account or session change.

The next functional phase uses only information and REST capabilities available in standard Ghostfolio. Ghostfolio-NG extensions require later evaluation; the existing integration does not imply that NG-specific functionality is implemented. See the [Roadmap](roadmap.md).

## Native resources

Android has its own startup splash, selected before Flutter initialization. Separate icon resources serve system light and dark themes. Native selection follows Android system appearance, independently of the user-selected Flutter theme.

## Verification

Navigation regression coverage is in [test/mobile_shell_test.dart](../test/mobile_shell_test.dart), with theme and Refresh integration in [test/theme_refresh_test.dart](../test/theme_refresh_test.dart). Build 29 validation is recorded in the [Changelog](../CHANGELOG.md).

Use `flutter analyze`, sequential `flutter test --concurrency=1`, then a device build and functional tests. A passing unit/widget suite does not prove Android lifecycle, authentication or financial API behavior on a device.
