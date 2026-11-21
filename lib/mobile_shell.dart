import 'package:material_ui/material_ui.dart';

import 'app_version_title.dart';
import 'activity_feed.dart';
import 'accounts_page.dart';
import 'portfolio_client.dart';
import 'holdings_page.dart';
import 'return_chart.dart';

/// M5 mobile shell. Tabs share one data snapshot; switching tabs makes no HTTP calls.
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
  int _tab = 0;
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
      _tab = 0;
      _range = 'max';
      _accountId = null;
      _accountName = null;
      _accountsFuture = null;
      _refresh();
    }
  }

  Future<_Snapshot> _fetch() async {
    final api = widget.client ?? PortfolioClient();
    final profile = await api.getProfile(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
    );
    final accountId = _accountId;
    final range = _range;
    final details = accountId == null
        ? await api.getDetails(serverUrl: widget.serverUrl, jwt: widget.jwt)
        : await api.getDetailsForAccount(
            serverUrl: widget.serverUrl,
            jwt: widget.jwt,
            accountId: accountId,
          );
    PortfolioHistory? history;
    String? historyIssue;
    try {
      history = accountId == null
          ? await api.getHistory(
              serverUrl: widget.serverUrl,
              jwt: widget.jwt,
              range: range,
            )
          : await api.getHistoryForAccount(
              serverUrl: widget.serverUrl,
              jwt: widget.jwt,
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
    return Scaffold(
      appBar: AppBar(
        title: const AppVersionTitle(),
        actions: [
          IconButton(
            tooltip: 'Select account',
            icon: const Icon(Icons.filter_list),
            onPressed: _openAccountSelector,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tab == 2) {
                _activityKey.currentState?.refresh();
              } else {
                setState(_refresh);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_Snapshot>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
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
            final data = snapshot.requireData;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: IndexedStack(
                  index: _tab,
                  children: [
                    _overview(data),
                    _holdings(data),
                    ActivityFeed(
                      key: _activityKey,
                      serverUrl: widget.serverUrl,
                      jwt: widget.jwt,
                      client: widget.client,
                      active: _tab == 2,
                      accountId: _accountId,
                    ),
                    _settings(data),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Holdings',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountOverview(String baseCurrency) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountsPage(
          serverUrl: widget.serverUrl,
          jwt: widget.jwt,
          baseCurrency: baseCurrency,
          selectedAccountId: _accountId,
          client: widget.client,
          onAccountSelected: (account) {
            final id = account?.id;
            if (!mounted || id == _accountId) return;
            setState(() {
              _accountId = id;
              _accountName = account?.name;
              _refresh();
            });
          },
        ),
      ),
    );
  }

  Future<void> _openAccountSelector() async {
    if (!mounted) return;
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
                      onTap: () => _chooseAccount(null, null, sheetContext),
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

  void _chooseAccount(String? id, String? name, BuildContext sheetContext) {
    Navigator.of(sheetContext).pop();
    if (!mounted || id == _accountId) return;
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
      ListTile(
        leading: const Icon(Icons.account_balance),
        title: const Text('Account overview'),
        subtitle: const Text('Balances, holdings and allocation'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAccountOverview(data.profile.baseCurrency ?? ''),
      ),
      ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: const Text('Accounts'),
        subtitle: Text(_accountName ?? 'All accounts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openAccountSelector,
      ),
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
