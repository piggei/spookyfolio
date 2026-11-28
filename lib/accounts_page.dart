import 'package:material_ui/material_ui.dart';

import 'account_detail_page.dart';
import 'portfolio_client.dart';

/// Read-only account overview. Values are supplied by Ghostfolio, never
/// synthesized by adding amounts denominated in different currencies.
class AccountsPage extends StatefulWidget {
  const AccountsPage({
    super.key,
    required this.serverUrl,
    required this.jwt,
    required this.baseCurrency,
    this.client,
    this.embedded = false,
    this.refreshRevision = 0,
  });

  final String serverUrl;
  final String jwt;
  final String baseCurrency;
  final PortfolioClient? client;
  final bool embedded;
  final int refreshRevision;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late Future<PortfolioAccountsCatalog> _catalog;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AccountsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.jwt != widget.jwt ||
        oldWidget.refreshRevision != widget.refreshRevision) {
      _reload();
    }
  }

  void _reload() {
    _catalog = (widget.client ?? PortfolioClient()).getAccountsCatalog(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
    );
  }

  String _amount(double? value, String? currency) {
    if (value == null) return 'Not available';
    return '${value.toStringAsFixed(2)}${currency == null || currency.isEmpty ? '' : ' $currency'}';
  }

  String _allocation(double? value) =>
      value == null ? 'Not available' : '${(value * 100).toStringAsFixed(2)}%';

  @override
  Widget build(BuildContext context) {
    final header = AppBar(
      title: const Text('Accounts'),
      actions: [
        IconButton(
          tooltip: 'Refresh accounts',
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
    final body = SafeArea(
      child: FutureBuilder<PortfolioAccountsCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load accounts.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(_reload),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = snapshot.requireData.accounts;
          return ListView(
            key: const ValueKey('accounts-overview-page'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Accounts (${accounts.length})',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Amounts are reported in their indicated currencies.'),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No accounts found.'),
                ),
              for (final account in accounts)
                Card(
                  key: ValueKey('account-${account.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(account.name),
                          subtitle: Text(
                            [
                              if (account.platformName != null)
                                account.platformName!,
                              account.currency,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AccountDetailPage(
                                account: account,
                                baseCurrency: widget.baseCurrency,
                                serverUrl: widget.serverUrl,
                                jwt: widget.jwt,
                                client: widget.client,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        if (account.balance != null)
                          _metric(
                            'Cash balance',
                            _amount(account.balance, account.currency),
                          ),
                        if (account.value != null)
                          _metric(
                            'Holdings value',
                            _amount(account.value, widget.baseCurrency),
                          ),
                        if (account.allocation != null)
                          _metric(
                            'Portfolio allocation',
                            _allocation(account.allocation),
                          ),
                        if (account.activitiesCount != null)
                          _metric(
                            'Transactions',
                            account.activitiesCount.toString(),
                          ),
                        if (account.dividends != null)
                          _metric(
                            'Dividends',
                            _amount(account.dividends, widget.baseCurrency),
                          ),
                        if (account.interest != null)
                          _metric(
                            'Interest',
                            _amount(account.interest, widget.baseCurrency),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(appBar: header, body: body);
  }

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
