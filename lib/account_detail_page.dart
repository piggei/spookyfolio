import 'package:material_ui/material_ui.dart';

import 'activity_feed.dart';
import 'account_financial_summary.dart';
import 'portfolio_client.dart';

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({
    super.key,
    required this.account,
    required this.baseCurrency,
    required this.serverUrl,
    required this.jwt,
    this.client,
  });

  final PortfolioAccount account;
  final String baseCurrency;
  final String serverUrl;
  final String jwt;
  final PortfolioClient? client;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  late final PageController _pages;
  final _activityKey = GlobalKey<ActivityFeedState>();

  late Future<PortfolioAccount> _account;
  Future<PortfolioAccountBalances>? _balances;
  Future<AccountFinancialSummary>? _financialSummary;

  int _section = 0;

  PortfolioClient get _api => widget.client ?? PortfolioClient();

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _loadAccount();
  }

  @override
  void didUpdateWidget(covariant AccountDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.account.id != widget.account.id ||
        oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.jwt != widget.jwt) {
      _loadAccount();
      _balances = null;
      _financialSummary = null;
      _section = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) {
          _pages.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _loadAccount() {
    _financialSummary = null;
    _account = _api.getAccountById(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
      accountId: widget.account.id,
    );
  }

  void _loadBalances() {
    _balances = _api.getAccountBalances(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
      accountId: widget.account.id,
    );
  }

  void _refresh() {
    if (_section == 0) {
      setState(_loadAccount);
    } else if (_section == 1) {
      setState(_loadBalances);
    } else {
      _activityKey.currentState?.refresh();
    }
  }

  void _selectSection(int index) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (index == 1 && _balances == null) {
      _loadBalances();
    }
    setState(() => _section = index);
  }

  String _money(double? value, String currency) {
    if (value == null) return 'Not available';
    return '${value.toStringAsFixed(2)}'
        '${currency.isEmpty ? '' : ' $currency'}';
  }

  String _percent(double? value) {
    if (value == null) return 'Not available';
    return '${(value * 100).toStringAsFixed(2)}%';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview() {
    return FutureBuilder<PortfolioAccount>(
      future: _account,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _errorPage(
            'Could not load account details.',
            () => setState(_loadAccount),
          );
        }

        final account = snapshot.requireData;

        if (account.id != widget.account.id) {
          return _errorPage(
            'Account details do not match the selected account.',
            () => setState(_loadAccount),
          );
        }

        _financialSummary ??= loadAccountFinancialSummary(
          client: _api,
          serverUrl: widget.serverUrl,
          jwt: widget.jwt,
          accountId: account.id,
        );
        return ListView(
          key: const ValueKey('account-detail-overview'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              account.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (account.platformName != null) Text(account.platformName!),
            const SizedBox(height: 16),
            Text(
              'Account details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _metric('Currency', account.currency),
            if (account.balance != null)
              _metric(
                'Cash balance',
                _money(account.balance, account.currency),
              ),
            if (account.value != null)
              _metric(
                'Holdings value',
                _money(account.value, widget.baseCurrency),
              ),
            if (account.allocation != null)
              _metric('Portfolio allocation', _percent(account.allocation)),
            if (account.activitiesCount != null)
              _metric('Transactions', account.activitiesCount.toString()),
            FutureBuilder<AccountFinancialSummary>(
              future: _financialSummary,
              builder: (context, summarySnapshot) {
                final summary = summarySnapshot.data;
                final taxesReconciled =
                    account.dividends != null &&
                    summary?.dividendTaxes != null &&
                    summary?.dividendGross != null &&
                    dividendsReconcile(
                      account.dividends!,
                      summary!.dividendGross!,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (summary?.tradingFees != null) ...[
                      const Divider(height: 24),
                      Text(
                        'Fees paid',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _metric(
                        'Trading fees',
                        _money(summary!.tradingFees, widget.baseCurrency),
                      ),
                    ],
                    if (account.interest != null) ...[
                      const Divider(height: 24),
                      Text(
                        'Interest',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _metric(
                        'Interest received',
                        _money(account.interest, widget.baseCurrency),
                      ),
                    ],
                    if (account.dividends != null) ...[
                      const Divider(height: 24),
                      Text(
                        'Dividends',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _metric(
                        'Gross dividends',
                        _money(account.dividends, widget.baseCurrency),
                      ),
                      if (taxesReconciled) ...[
                        _metric(
                          'Of which taxes',
                          _money(summary.dividendTaxes, widget.baseCurrency),
                        ),
                        _metric(
                          'Net dividends',
                          _money(
                            account.dividends! - summary.dividendTaxes!,
                            widget.baseCurrency,
                          ),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Cash balance is shown in the account currency. '
              'Holdings value and dividends are shown in the '
              'portfolio base currency.',
            ),
          ],
        );
      },
    );
  }

  Widget _balancesPage() {
    final future = _balances;

    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<PortfolioAccountBalances>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _errorPage(
            'Could not load account balance history.',
            () => setState(_loadBalances),
          );
        }

        final balances = [...snapshot.requireData.balances]
          ..sort((a, b) => b.date.compareTo(a.date));

        return ListView(
          key: const ValueKey('account-detail-balances'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Balance history (${balances.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'These are recorded account balances, '
              'not necessarily deposits or withdrawals.',
            ),
            const SizedBox(height: 12),
            if (balances.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recorded balances.'),
              ),
            for (final balance in balances)
              Card(
                key: ValueKey('balance-${balance.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _date(balance.date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _metric(
                        'Balance',
                        _money(balance.value, widget.account.currency),
                      ),
                      if (widget.baseCurrency.isNotEmpty)
                        _metric(
                          'Base currency value',
                          _money(
                            balance.valueInBaseCurrency,
                            widget.baseCurrency,
                          ),
                        ),
                      if (balance.comment != null &&
                          balance.comment!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(balance.comment!),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _errorPage(String message, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        actions: [
          IconButton(
            tooltip: 'Refresh account section',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: PageView(
          key: const ValueKey('account-detail-pages'),
          controller: _pages,
          onPageChanged: _onPageChanged,
          children: [
            _overview(),
            _balancesPage(),
            _AccountActivityKeepAlive(
              child: ActivityFeed(
                key: _activityKey,
                baseCurrency: widget.baseCurrency,
                serverUrl: widget.serverUrl,
                jwt: widget.jwt,
                accountId: widget.account.id,
                active: _section == 2,
                client: widget.client,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: _selectSection,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Overview',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Balances'),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Activity',
          ),
        ],
      ),
    );
  }
}

class _AccountActivityKeepAlive extends StatefulWidget {
  const _AccountActivityKeepAlive({required this.child});

  final Widget child;

  @override
  State<_AccountActivityKeepAlive> createState() =>
      _AccountActivityKeepAliveState();
}

class _AccountActivityKeepAliveState extends State<_AccountActivityKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
