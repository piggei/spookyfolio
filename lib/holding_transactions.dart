import 'package:material_ui/material_ui.dart';

import 'activity_detail_page.dart';
import 'activity_feed.dart';
import 'activity_models.dart';
import 'portfolio_client.dart';

/// Read-only, server-filtered transactions for one exact holding.
class HoldingTransactions extends StatefulWidget {
  const HoldingTransactions({
    super.key,
    required this.serverUrl,
    required this.jwt,
    required this.dataSource,
    required this.symbol,
    this.baseCurrency = '',
    this.client,
  });

  final String serverUrl;
  final String jwt;
  final String dataSource;
  final String symbol;
  final String baseCurrency;
  final PortfolioClient? client;

  @override
  State<HoldingTransactions> createState() => _HoldingTransactionsState();
}

class _HoldingTransactionsState extends State<HoldingTransactions> {
  static const _pageSize = 20;
  final _items = <PortfolioActivity>[];
  final _seen = <String>{};
  int _offset = 0;
  int _count = 0;
  int _generation = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HoldingTransactions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.jwt != widget.jwt ||
        oldWidget.dataSource != widget.dataSource ||
        oldWidget.symbol != widget.symbol) {
      _generation++;
      _items.clear();
      _seen.clear();
      _offset = 0;
      _count = 0;
      _loaded = false;
      _loading = false;
      _error = null;
      _load();
    }
  }

  Future<void> _openActivity(PortfolioActivity activity) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          activityId: activity.id,
          serverUrl: widget.serverUrl,
          jwt: widget.jwt,
          baseCurrency: widget.baseCurrency,
          client: widget.client,
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (_loading) return;
    final generation = _generation;
    final offset = _offset;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batch = await (widget.client ?? PortfolioClient())
          .getHoldingActivities(
            serverUrl: widget.serverUrl,
            jwt: widget.jwt,
            dataSource: widget.dataSource,
            symbol: widget.symbol,
            skip: offset,
            take: _pageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _count = batch.count;
        _offset += batch.activities.length;
        for (final item in batch.activities) {
          if (_seen.add(item.id)) _items.add(item);
        }
        _items.sort((a, b) => b.date.compareTo(a.date));
        _loaded = true;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error is PortfolioApiException
            ? error.message
            : 'Unable to load holding transactions.';
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Transactions', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      if (_loaded)
        Text(
          '$_count transactions',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (_loaded && _items.isEmpty && _error == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No transactions for this asset.'),
        ),
      for (final item in _items)
        ActivityCard(activity: item, onTap: () => _openActivity(item)),
      if (_error != null) ...[
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Retry transactions'),
        ),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_loaded && !_loading && _error == null && _offset < _count)
        OutlinedButton(
          onPressed: _load,
          child: Text('Load more (${_items.length} of $_count)'),
        ),
    ],
  );
}
