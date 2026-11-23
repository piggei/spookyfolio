import 'package:material_ui/material_ui.dart';

import 'app_version_title.dart';
import 'about_page.dart';
import 'activity_feed.dart';
import 'accounts_page.dart';
import 'portfolio_client.dart';
import 'holdings_page.dart';
import 'return_chart.dart';

/// Hierarchical shell. Navigation shares a snapshot and retains visited pages.
class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.serverUrl,
    required this.jwt,
    required this.onSignOut,
    this.edition = 'Ghostfolio',
    this.client,
    this.themeMode = ThemeMode.dark,
    this.onThemeChanged,
  });

  final String serverUrl;
  final String jwt;
  final String edition;
  final Future<void> Function() onSignOut;
  final PortfolioClient? client;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode)? onThemeChanged;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  static const _ranges = <String>['1d', 'wtd', 'mtd', 'ytd', '1y', '5y', 'max'];

  late Future<_Snapshot> _data;
  _Snapshot? _lastSnapshot;
  int _sessionRevision = 0;
  _ShellNavigation _navigation = _ShellNavigation();
  final _menuController = MenuController();
  bool _menuOpen = false;
  int _accountsRefreshRevision = 0;
  String _range = 'max';
  String? _accountId;
  String? _accountName;
  Future<PortfolioAccountsCatalog>? _accountsFuture;
  final _activityKey = GlobalKey<ActivityFeedState>();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant MobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jwt != oldWidget.jwt ||
        widget.serverUrl != oldWidget.serverUrl) {
      _navigation = _ShellNavigation();
      _accountsRefreshRevision = 0;
      _range = 'max';
      _accountId = null;
      _accountName = null;
      _accountsFuture = null;
      _lastSnapshot = null;
      _sessionRevision++;
      final revision = _sessionRevision;
      final shellRoute = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _sessionRevision) return;
        _menuController.close();
        // Detail routes and account sheets also belong to the old session.
        if (shellRoute != null && shellRoute.isActive) {
          Navigator.of(context).popUntil((route) => route == shellRoute);
        }
      });
      _refresh();
    }
  }

  Future<_Snapshot> _fetch() async {
    final api = widget.client ?? PortfolioClient();
    // Capture the request context before awaiting to isolate in-flight sessions.
    final serverUrl = widget.serverUrl;
    final jwt = widget.jwt;
    final accountId = _accountId;
    final range = _range;
    final profile = await api.getProfile(serverUrl: serverUrl, jwt: jwt);
    final details = accountId == null
        ? await api.getDetails(serverUrl: serverUrl, jwt: jwt)
        : await api.getDetailsForAccount(
            serverUrl: serverUrl,
            jwt: jwt,
            accountId: accountId,
          );
    PortfolioHistory? history;
    String? historyIssue;
    try {
      history = accountId == null
          ? await api.getHistory(serverUrl: serverUrl, jwt: jwt, range: range)
          : await api.getHistoryForAccount(
              serverUrl: serverUrl,
              jwt: jwt,
              accountId: accountId,
              range: range,
            );
    } catch (error) {
      historyIssue = error is PortfolioApiException
          ? error.message
          : 'Historical data unavailable';
    }
    return _Snapshot(profile, details, history, historyIssue);
  }

  void _refresh() {
    _data = _fetch();
  }

  void _changeRange(String range) {
    if (range == _range) return;
    setState(() {
      _range = range;
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_menuOpen && !_navigation.canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_menuOpen) {
          _menuController.close();
        } else if (_navigation.canGoBack) {
          setState(_navigation.goBack);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const AppVersionTitle(),
          actions: [
            if (_navigation.section != _Section.settings)
              IconButton(
                tooltip: 'Select account',
                icon: const Icon(Icons.filter_list),
                onPressed: _openAccountSelector,
              ),
            _mainMenu(),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<_Snapshot>(
            key: ValueKey('portfolio-snapshot-$_sessionRevision'),
            future: _data,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState != ConnectionState.done;

              if (!loading && snapshot.hasData) {
                _lastSnapshot = snapshot.requireData;
              }

              final displayData = snapshot.hasData
                  ? snapshot.requireData
                  : _lastSnapshot;

              if (loading && displayData == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError && displayData == null) {
                final error = snapshot.error;
                final message = error is PortfolioApiException
                    ? error.message
                    : 'Could not load portfolio data.';

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42),
                        const SizedBox(height: 12),
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => setState(_refresh),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = displayData!;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: IndexedStack(
                        key: ValueKey('section-pages-$_sessionRevision'),
                        index: _navigation.section.index,
                        children: [
                          for (final section in _Section.values)
                            _SectionPages(
                              key: ValueKey(section),
                              section: section,
                              selectedIndex: _navigation.indexFor(section),
                              active: _navigation.section == section,
                              onChanged: (index) => setState(
                                () => _navigation.selectSubsection(
                                  section,
                                  index,
                                ),
                              ),
                              pageBuilder: (destination) =>
                                  switch (destination) {
                                    _Destination.overview => _overview(data),
                                    _Destination.holdings => _holdings(data),
                                    _Destination.accounts => AccountsPage(
                                      serverUrl: widget.serverUrl,
                                      jwt: widget.jwt,
                                      baseCurrency:
                                          data.profile.baseCurrency ?? '',
                                      client: widget.client,
                                      embedded: true,
                                      refreshRevision: _accountsRefreshRevision,
                                    ),
                                    _Destination.activity => ActivityFeed(
                                      key: _activityKey,
                                      enableAssetFilter: true,
                                      baseCurrency:
                                          data.profile.baseCurrency ?? '',
                                      serverUrl: widget.serverUrl,
                                      jwt: widget.jwt,
                                      client: widget.client,
                                      active:
                                          _navigation.destination ==
                                          _Destination.activity,
                                      accountId: _accountId,
                                    ),
                                    _Destination.preferences => _settings(data),
                                    _Destination.about =>
                                      const SpookyfolioAboutPage(
                                        embedded: true,
                                      ),
                                  },
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (loading || snapshot.hasError)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: Center(
                          child: snapshot.hasError
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cloud_off_outlined),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Could not update portfolio data.',
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: () => setState(_refresh),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                )
                              : const CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _mainMenu() => MenuAnchor(
    controller: _menuController,
    onOpen: () => setState(() => _menuOpen = true),
    onClose: () => setState(() => _menuOpen = false),
    menuChildren: [
      for (final section in _Section.values)
        MenuItemButton(
          key: ValueKey('section-${section.name}'),
          leadingIcon: Icon(section.icon),
          trailingIcon: _navigation.section == section
              ? const Icon(Icons.check)
              : null,
          style: _navigation.section == section
              ? ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.secondaryContainer,
                  ),
                )
              : null,
          onPressed: () => setState(() => _navigation.selectSection(section)),
          child: Text(section.label),
        ),
      const Divider(),
      MenuItemButton(
        key: const ValueKey('refresh-navigation'),
        leadingIcon: const Icon(Icons.refresh),
        onPressed: _navigation.section == _Section.settings
            ? null
            : _refreshCurrentDestination,
        child: const Text('Refresh'),
      ),
    ],
    builder: (context, controller, child) => IconButton(
      key: const ValueKey('main-navigation'),
      tooltip: 'Navigation menu',
      icon: const Icon(Icons.more_vert),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );

  void _refreshCurrentDestination() {
    switch (_navigation.destination) {
      case _Destination.accounts:
        setState(() => _accountsRefreshRevision++);
      case _Destination.activity:
        _activityKey.currentState?.refresh();
      case _Destination.overview:
      case _Destination.holdings:
        setState(_refresh);
      case _Destination.preferences:
      case _Destination.about:
        return;
    }
  }

  Future<void> _openAccountSelector() async {
    if (!mounted) return;
    final sessionRevision = _sessionRevision;
    _accountsFuture ??= (widget.client ?? PortfolioClient()).getAccountsCatalog(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: FutureBuilder<PortfolioAccountsCatalog>(
              future: _accountsFuture,
              builder: (sheetContext, snapshot) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Accounts are unavailable. Check account permissions or network.',
                          ),
                          TextButton(
                            onPressed: () => updateSheet(() {
                              _accountsFuture =
                                  (widget.client ?? PortfolioClient())
                                      .getAccountsCatalog(
                                        serverUrl: widget.serverUrl,
                                        jwt: widget.jwt,
                                      );
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final accounts = snapshot.requireData.accounts;
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    const ListTile(title: Text('Select account')),
                    ListTile(
                      title: const Text('All accounts'),
                      leading: Icon(
                        _accountId == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      onTap: () => _chooseAccount(
                        null,
                        null,
                        sheetContext,
                        sessionRevision,
                      ),
                    ),
                    for (final account in accounts)
                      ListTile(
                        title: Text(account.name),
                        subtitle: Text(
                          [
                            if (account.platformName != null)
                              account.platformName!,
                            account.currency,
                          ].join(' · '),
                        ),
                        leading: Icon(
                          _accountId == account.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: () => _chooseAccount(
                          account.id,
                          account.name,
                          sheetContext,
                          sessionRevision,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _chooseAccount(
    String? id,
    String? name,
    BuildContext sheetContext,
    int sessionRevision,
  ) {
    Navigator.of(sheetContext).pop();
    if (!mounted || sessionRevision != _sessionRevision || id == _accountId) {
      return;
    }
    setState(() {
      _accountId = id;
      _accountName = name;
      _refresh();
    });
  }

  Widget _overview(_Snapshot data) {
    final history = data.history;
    final currency = data.profile.baseCurrency ?? '';
    final value = history?.portfolioValue;
    final delta = history?.changeWithCurrencyEffect;
    final performance =
        history?.returnPercentageWithCurrencyEffect ??
        data.details.netPerformancePercentage;
    final method = data.profile.performanceCalculationType;
    final points =
        history?.points
            .where((point) => point.returnWithCurrencyEffect != null)
            .toList() ??
        <PortfolioPoint>[];
    points.sort((a, b) => a.date.compareTo(b.date));
    return ListView(
      key: const ValueKey('overview-page'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        if (_accountName != null) ...[
          Text(
            'Account: $_accountName',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
        ],
        const Text('Portfolio value'),
        const SizedBox(height: 4),
        Text(
          _money(value, currency),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 5),
        Text(
          '${_percentage(performance)}  ·  ${method ?? 'Return'} incl. currency effect',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final range in _ranges)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ChoiceChip(
                    label: Text(range.toUpperCase()),
                    selected: _range == range,
                    onSelected: (_) => _changeRange(range),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (data.historyIssue != null)
          Text(data.historyIssue!)
        else if (points.length < 2)
          const SizedBox(
            height: 180,
            child: Center(
              child: Text('No historical return data for this period'),
            ),
          )
        else
          InteractiveReturnChart(points: points),
        const SizedBox(height: 22),
        Text('At a glance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tile('Change incl. FX', _money(delta, currency), width),
                _tile('Return incl. FX', _percentage(performance), width),
                _tile(
                  'Invested',
                  _money(data.details.investedValue, currency),
                  width,
                ),
                _tile('Cash', _money(data.details.cash, currency), width),
              ],
            );
          },
        ),
        if (data.details.hasError) ...[
          const SizedBox(height: 12),
          const Text(
            'Ghostfolio reports incomplete portfolio data.',
            style: TextStyle(color: Colors.orangeAccent),
          ),
        ],
      ],
    );
  }

  Widget _tile(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 7),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _holdings(_Snapshot data) => HoldingsPage(
    holdings: data.details.holdings,
    baseCurrency: data.profile.baseCurrency ?? '',
    serverUrl: widget.serverUrl,
    jwt: widget.jwt,
    client: widget.client,
    accountFiltered: _accountId != null,
  );

  Widget _settings(_Snapshot data) => ListView(
    key: const ValueKey('settings-page'),
    padding: const EdgeInsets.all(20),
    children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 18),
      Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final choice in ThemeMode.values)
            ChoiceChip(
              key: ValueKey('theme-${choice.name}'),
              label: Text(switch (choice) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              }),
              selected: widget.themeMode == choice,
              onSelected: widget.onThemeChanged == null
                  ? null
                  : (_) async {
                      try {
                        await widget.onThemeChanged!(choice);
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not save theme preference'),
                          ),
                        );
                      }
                    },
            ),
        ],
      ),
      const Divider(),
      ListTile(title: const Text('Server'), subtitle: Text(widget.serverUrl)),
      ListTile(title: const Text('Edition'), subtitle: Text(widget.edition)),
      ListTile(
        title: const Text('Base currency'),
        subtitle: Text(data.profile.baseCurrency ?? 'Not specified'),
      ),
      ListTile(
        title: const Text('Performance method'),
        subtitle: Text(
          data.profile.performanceCalculationType ?? 'Not specified',
        ),
      ),
      const Divider(),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async => widget.onSignOut(),
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class _Snapshot {
  const _Snapshot(this.profile, this.details, this.history, this.historyIssue);
  final GhostfolioProfile profile;
  final PortfolioSnapshot details;
  final PortfolioHistory? history;
  final String? historyIssue;
}

String _money(double? amount, String currency) => amount == null
    ? 'Not available'
    : '${amount.toStringAsFixed(2)}${currency.isEmpty ? '' : ' $currency'}';

String _percentage(double? ratio) =>
    ratio == null ? 'Not available' : '${(ratio * 100).toStringAsFixed(2)}%';

enum _Destination {
  overview('Overview', Icons.dashboard_outlined),
  holdings('Holdings', Icons.account_balance_wallet_outlined),
  accounts('Accounts', Icons.account_balance_outlined),
  activity('Activity', Icons.swap_horiz),
  preferences('Preferences', Icons.settings_outlined),
  about('About', Icons.info_outline);

  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum _Section {
  dashboard('Dashboard', Icons.dashboard_outlined, [_Destination.overview]),
  portfolio('Portfolio', Icons.account_balance_wallet_outlined, [
    _Destination.holdings,
    _Destination.accounts,
    _Destination.activity,
  ]),
  settings('Settings', Icons.settings_outlined, [
    _Destination.preferences,
    _Destination.about,
  ]);

  const _Section(this.label, this.icon, this.destinations);
  final String label;
  final IconData icon;
  final List<_Destination> destinations;
}

/// The sole navigation state: section history and remembered subsection per section.
/// Account selection and performance range deliberately live outside this model.
class _ShellNavigation {
  _Section section = _Section.dashboard;
  final _indices = <_Section, int>{};
  final _history = <_Section>[];

  int indexFor(_Section section) => _indices[section] ?? 0;
  _Destination get destination => section.destinations[indexFor(section)];
  bool get canGoBack => _history.isNotEmpty;

  void selectSection(_Section next) {
    if (next == section) return;
    if (next == _Section.dashboard) {
      _history.clear();
    } else {
      _history.add(section);
    }
    section = next;
  }

  void selectSubsection(_Section section, int index) =>
      _indices[section] = index;

  void goBack() => section = _history.removeLast();
}

/// Tab controllers handle gestures only; the shell owns navigation state.
class _SectionPages extends StatefulWidget {
  const _SectionPages({
    super.key,
    required this.section,
    required this.selectedIndex,
    required this.active,
    required this.onChanged,
    required this.pageBuilder,
  });

  final _Section section;
  final int selectedIndex;
  final bool active;
  final ValueChanged<int> onChanged;
  final Widget Function(_Destination) pageBuilder;

  @override
  State<_SectionPages> createState() => _SectionPagesState();
}

class _SectionPagesState extends State<_SectionPages>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: widget.section.destinations.length,
      initialIndex: widget.selectedIndex,
      vsync: this,
    );
    _tabs.addListener(_onChanged);
  }

  void _onChanged() {
    if (_tabs.index != widget.selectedIndex) widget.onChanged(_tabs.index);
  }

  @override
  void didUpdateWidget(covariant _SectionPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs.index != widget.selectedIndex) _tabs.index = widget.selectedIndex;
  }

  @override
  void dispose() {
    _tabs.removeListener(_onChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = widget.section.destinations;
    Widget page(int index) => _RetainedPage(
      active: widget.active && widget.selectedIndex == index,
      builder: () => widget.pageBuilder(destinations[index]),
    );
    if (destinations.length == 1) return page(0);
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            key: ValueKey('${widget.section.name}-swipe-pages'),
            controller: _tabs,
            children: [
              for (var index = 0; index < destinations.length; index++)
                page(index),
            ],
          ),
        ),
        NavigationBar(
          key: ValueKey('subsections-${widget.section.name}'),
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: _tabs.animateTo,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                key: ValueKey('destination-${destination.name}'),
                icon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      ],
    );
  }
}

/// Mount on first selection, then preserve data, scroll position and pagination.
class _RetainedPage extends StatefulWidget {
  const _RetainedPage({required this.active, required this.builder});
  final bool active;
  final Widget Function() builder;

  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage>
    with AutomaticKeepAliveClientMixin {
  late bool _visited;

  @override
  void initState() {
    super.initState();
    _visited = widget.active;
  }

  @override
  void didUpdateWidget(covariant _RetainedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_visited && widget.active) {
      _visited = true;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _visited ? widget.builder() : const SizedBox.shrink();
  }
}
