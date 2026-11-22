import 'package:material_ui/material_ui.dart';

import 'activity_models.dart';
import 'portfolio_client.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.activityId,
    required this.serverUrl,
    required this.jwt,
    required this.baseCurrency,
    this.client,
  });

  final String activityId;
  final String serverUrl;
  final String jwt;
  final String baseCurrency;
  final PortfolioClient? client;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late Future<PortfolioActivity> _activity;

  PortfolioClient get _api => widget.client ?? PortfolioClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ActivityDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.activityId != widget.activityId ||
        oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.jwt != widget.jwt ||
        oldWidget.client != widget.client) {
      _load();
    }
  }

  void _load() {
    _activity = _api.getActivityById(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
      activityId: widget.activityId,
    );
  }

  void _refresh() => setState(_load);

  String _number(double? value, {int digits = 2}) =>
      value == null ? 'Not available' : value.toStringAsFixed(digits);

  String _money(double? value, String? currency) {
    if (value == null) return 'Not available';
    final amount = _number(value);
    return currency == null || currency.isEmpty ? amount : '$amount $currency';
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
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

  Widget _error(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _refresh, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _details(PortfolioActivity activity) {
    final currency = activity.currency;
    final assetCurrency = activity.assetCurrency;
    final baseCurrency = widget.baseCurrency;

    return ListView(
      key: const ValueKey('activity-detail-content'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          activity.name ?? activity.symbol ?? activity.type,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(activity.type, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(
          _money(activity.value, currency),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Text('Transaction', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _metric('Date', _date(activity.date)),
        _metric('Type', activity.type),
        if (activity.symbol != null) _metric('Symbol', activity.symbol!),
        if (activity.dataSource != null)
          _metric('Data source', activity.dataSource!),
        if (activity.isin != null) _metric('ISIN', activity.isin!),
        _metric('Quantity', _number(activity.quantity, digits: 4)),
        _metric('Unit price', _money(activity.unitPrice, currency)),
        _metric('Fee', _money(activity.fee, currency)),
        _metric('Value', _money(activity.value, currency)),
        if (activity.accountName != null)
          _metric('Account', activity.accountName!),
        if (activity.comment != null) ...[
          const SizedBox(height: 16),
          Text('Comment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(activity.comment!),
        ],
        if (activity.valueInBaseCurrency != null ||
            activity.feeInBaseCurrency != null) ...[
          const SizedBox(height: 20),
          Text(
            'Portfolio base currency',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (activity.valueInBaseCurrency != null)
            _metric(
              'Value',
              _money(activity.valueInBaseCurrency, baseCurrency),
            ),
          if (activity.feeInBaseCurrency != null)
            _metric('Fee', _money(activity.feeInBaseCurrency, baseCurrency)),
        ],
        if (activity.unitPriceInAssetProfileCurrency != null ||
            activity.feeInAssetProfileCurrency != null) ...[
          const SizedBox(height: 20),
          Text('Asset currency', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (activity.unitPriceInAssetProfileCurrency != null)
            _metric(
              'Unit price',
              _money(activity.unitPriceInAssetProfileCurrency, assetCurrency),
            ),
          if (activity.feeInAssetProfileCurrency != null)
            _metric(
              'Fee',
              _money(activity.feeInAssetProfileCurrency, assetCurrency),
            ),
        ],
        if (activity.createdAt != null || activity.updatedAt != null) ...[
          const SizedBox(height: 20),
          Text('Metadata', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (activity.createdAt != null)
            _metric('Created', _date(activity.createdAt!)),
          if (activity.updatedAt != null)
            _metric('Updated', _date(activity.updatedAt!)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction details'),
        actions: [
          IconButton(
            tooltip: 'Refresh transaction',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<PortfolioActivity>(
          future: _activity,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final message =
                  error is PortfolioApiException && error.statusCode == 404
                  ? 'Transaction not found.'
                  : 'Could not load transaction details.';
              return _error(message);
            }

            final activity = snapshot.requireData;

            if (activity.id != widget.activityId) {
              return _error(
                'Transaction details do not match the selected operation.',
              );
            }

            return _details(activity);
          },
        ),
      ),
    );
  }
}
