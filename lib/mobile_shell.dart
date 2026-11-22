import 'package:material_ui/material_ui.dart';

import 'app_version_title.dart';
import 'about_page.dart';
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
  late PageController _rootPages;
  late final PageController _portfolioPages;
  late final PageController _morePages;
  int? _contextTab;
  int _contextReturnTab = 0;
  bool _restoringRootPage = false;
  int _portfolioTab = 0;
  int _moreTab = 0;
  int _accountsRefreshRevision = 0;
  String _range = 'max';
  String? _accountId;
  String? _accountName;
  Future<PortfolioAccountsCatalog>? _accountsFuture;
  final _activityKey = GlobalKey<ActivityFeedState>();

  @override
  void initState() {
    super.initState();
    _rootPages = PageController();
    _portfolioPages = PageController();
    _morePages = PageController();
    _refresh();
  }

  @override
  void dispose() {
    _rootPages.dispose();
    _portfolioPages.dispose();
    _morePages.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jwt != oldWidget.jwt ||
        widget.serverUrl != oldWidget.serverUrl) {
      _tab = 0;
      _contextTab = null;
      _contextReturnTab = 0;
      _restoringRootPage = false;
      _portfolioTab = 0;
      _moreTab = 0;
      _accountsRefreshRevision = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _rootPages.hasClients) {
          _rootPages.jumpToPage(0);
        }
      });
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
    return PopScope(
      canPop: _contextTab == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _contextTab != null) {
          _exitContext();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _contextTab == 1
              ? const Text('Portfolio')
              : _contextTab == 3
              ? Text(_moreTab == 0 ? 'Settings' : 'About')
              : const AppVersionTitle(),
          leading: _contextTab == null
              ? null
              : BackButton(onPressed: _exitContext),
          actions: [
            if (_contextTab != 3)
              IconButton(
                tooltip: 'Select account',
                icon: const Icon(Icons.filter_list),
                onPressed: _openAccountSelector,
              ),
            if (_contextTab != 3)
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (_contextTab == 1 && _portfolioTab == 1) {
                    setState(() => _accountsRefreshRevision++);
                  } else if (_contextTab == null && _tab == 2) {
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
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onRootScrollEnd,
                    child: PageView(
                      key: const ValueKey('root-swipe-pages'),
                      controller: _rootPages,
                      physics: _contextTab == null
                          ? const PageScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        if (_tab != index) {
                          setState(() => _tab = index);
                        }
                      },
                      children: [
                        _overview(data),
                        _portfolioContent(data),
                        _RootKeepAlive(
                          child: ActivityFeed(
                            key: _activityKey,
                            serverUrl: widget.serverUrl,
                            jwt: widget.jwt,
                            client: widget.client,
                            active: _tab == 2,
                            accountId: _accountId,
                          ),
                        ),
                        _moreContent(data),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget _bottomBar() {
    if (_contextTab == 1) {
      return NavigationBar(
        selectedIndex: _portfolioTab,
        onDestinationSelected: (index) => _portfolioPages.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Holdings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            label: 'Accounts',
          ),
        ],
      );
    }

    if (_contextTab == 3) {
      return NavigationBar(
        selectedIndex: _moreTab,
        onDestinationSelected: (index) => _morePages.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      );
    }

    return NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _selectRootDestination,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.show_chart), label: 'Overview'),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Portfolio',
        ),
        NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Activity'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  void _selectRootDestination(int index) {
    if (!mounted || _contextTab != null || index < 0 || index > 3) {
      return;
    }

    if (!_rootPages.hasClients) {
      if (index == 1 || index == 3) {
        _contextReturnTab = _tab;
      }
      setState(() => _tab = index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_rootPages.hasClients) {
          _rootPages.jumpToPage(index);
        }
        _enterContext(index);
      });
      return;
    }

    final current = _rootPages.page;

    if (index == _tab && current != null && (current - index).abs() < 0.01) {
      _enterContext(index);
      return;
    }

    _rootPages.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _onRootScrollEnd(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.depth == 0 &&
        notification.metrics is PageMetrics &&
        _contextTab == null &&
        !_restoringRootPage) {
      _contextReturnTab = _tab;
    }

    if (notification is! ScrollEndNotification || _restoringRootPage) {
      return false;
    }

    if (_contextTab != null ||
        notification.depth != 0 ||
        notification.metrics is! PageMetrics ||
        !_rootPages.hasClients) {
      return false;
    }

    final page = _rootPages.page;
    if (page == null) return false;

    final index = page.round();

    if ((page - index).abs() > 0.01 || (index != 1 && index != 3)) {
      return false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _contextTab != null || !_rootPages.hasClients) {
        return;
      }

      final current = _rootPages.page;

      if (current != null && (current - index).abs() < 0.01 && _tab == index) {
        _enterContext(index);
      }
    });

    return false;
  }

  void _enterContext(int index) {
    if (!mounted || _contextTab != null || (index != 1 && index != 3)) {
      return;
    }

    final controller = index == 1 ? _portfolioPages : _morePages;

    if (controller.hasClients) {
      controller.jumpToPage(0);
    }

    setState(() {
      _contextTab = index;
      if (index == 1) {
        _portfolioTab = 0;
      } else {
        _moreTab = 0;
      }
    });
  }

  void _exitContext() {
    if (!mounted || _contextTab == null) return;

    final destination = _contextReturnTab;
    _restoringRootPage = true;

    // Restore the underlying page before displaying the root menu.
    if (_rootPages.hasClients) {
      _rootPages.jumpToPage(destination);
    }

    setState(() {
      _tab = destination;
      _contextTab = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoringRootPage = false;
      }
    });
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

  // Portfolio replaces the root NavigationBar with its own two destinations.
  // Popping the route restores the root bar with Portfolio selected.
  Widget _portfolioContent(_Snapshot data) {
    return PageView(
      key: const ValueKey('portfolio-swipe-pages'),
      controller: _portfolioPages,
      physics: _contextTab == 1
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (_portfolioTab != index) {
          setState(() => _portfolioTab = index);
        }
      },
      children: [
        _holdings(data),
        AccountsPage(
          serverUrl: widget.serverUrl,
          jwt: widget.jwt,
          baseCurrency: data.profile.baseCurrency ?? '',
          client: widget.client,
          embedded: true,
          refreshRevision: _accountsRefreshRevision,
        ),
      ],
    );
  }

  Widget _moreContent(_Snapshot data) {
    return PageView(
      key: const ValueKey('more-swipe-pages'),
      controller: _morePages,
      physics: _contextTab == 3
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (_moreTab != index) {
          setState(() => _moreTab = index);
        }
      },
      children: [_settings(data), const SpookyfolioAboutPage(embedded: true)],
    );
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

/// Keeps the activity feed and its pagination alive across root pages.
class _RootKeepAlive extends StatefulWidget {
  const _RootKeepAlive({required this.child});

  final Widget child;

  @override
  State<_RootKeepAlive> createState() => _RootKeepAliveState();
}

class _RootKeepAliveState extends State<_RootKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
