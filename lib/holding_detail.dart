import 'package:material_ui/material_ui.dart';

import 'holding_detail_data.dart';
import 'holding_price_chart.dart';
import 'holding_transactions.dart';
import 'portfolio_client.dart';

/// Independent detail route; the Holdings tab remains mounted underneath.
class HoldingDetailPage extends StatefulWidget {
  const HoldingDetailPage({
    super.key,
    required this.holding,
    required this.baseCurrency,
    required this.serverUrl,
    required this.jwt,
    this.client,
    this.loadDetail,
  });

  final PortfolioHolding holding;
  final String baseCurrency;
  final String serverUrl;
  final String jwt;
  final PortfolioClient? client;
  final Future<HoldingDetailData> Function()? loadDetail;

  @override
  State<HoldingDetailPage> createState() => _HoldingDetailPageState();
}

class _HoldingDetailPageState extends State<HoldingDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Future<HoldingDetailData>? _detail;
  bool _transactionsOpened = false;

  bool get _isCash =>
      widget.holding.symbol == widget.holding.name &&
      RegExp(r'^[A-Z]{3}$').hasMatch(widget.holding.symbol);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    if (_tabs.index == 2 && !_transactionsOpened && mounted) {
      setState(() => _transactionsOpened = true);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _load() {
    if (widget.loadDetail != null) {
      _detail = widget.loadDetail!();
    } else if (_isCash ||
        widget.holding.dataSource == null ||
        widget.holding.dataSource!.isEmpty) {
      _detail = null;
    } else {
      _detail = (widget.client ?? PortfolioClient()).getHoldingDetail(
        serverUrl: widget.serverUrl,
        jwt: widget.jwt,
        dataSource: widget.holding.dataSource!,
        symbol: widget.holding.symbol,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.holding.symbol)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_detail == null)
            Expanded(
              child: ListView(
                key: const ValueKey('holding-cash-page'),
                padding: const EdgeInsets.all(18),
                children: [
                  _Metric(
                    'Current value',
                    _money(widget.holding.value, widget.baseCurrency),
                  ),
                  const SizedBox(height: 8),
                  _Metric('Allocation', _percent(widget.holding.allocation)),
                  const SizedBox(height: 18),
                  Text(
                    _isCash ? 'Cash balance' : 'Position details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCash
                        ? 'Cash holdings do not have a market price or an average purchase price.'
                        : 'Detailed data are not available for this position.',
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: FutureBuilder<HoldingDetailData>(
                future: _detail,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    if (error is PortfolioApiException &&
                        error.statusCode == 404) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Additional details are not available for this holding.',
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        Text(
                          error is PortfolioApiException
                              ? error.message
                              : error is FormatException
                              ? error.message
                              : 'Could not load position details.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(_load),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ),
                      ],
                    );
                  }
                  final item = snapshot.requireData;
                  return Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _analysisTab(item),
                            _assetTab(item),
                            _ActivityTab(
                              enabled: _transactionsOpened,
                              serverUrl: widget.serverUrl,
                              jwt: widget.jwt,
                              dataSource: widget.holding.dataSource,
                              symbol: widget.holding.symbol,
                              client: widget.client,
                            ),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: TabBar(
                          controller: _tabs,
                          tabs: const [
                            Tab(text: 'Analysis', icon: Icon(Icons.show_chart)),
                            Tab(text: 'Asset', icon: Icon(Icons.info_outline)),
                            Tab(text: 'Activity', icon: Icon(Icons.swap_horiz)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _analysisTab(HoldingDetailData item) {
    final assetCurrency = item.assetCurrency ?? widget.baseCurrency;
    return ListView(
      key: const ValueKey('holding-analysis-tab'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        Text(
          widget.holding.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _SummaryStrip(
          value: _money(widget.holding.value, widget.baseCurrency),
          allocation: _percent(widget.holding.allocation),
          performance: _percent(widget.holding.netPerformancePercent),
        ),
        const SizedBox(height: 18),
        if (item.history.isNotEmpty) ...[
          Text(
            'Market price and average cost',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          HoldingPriceChart(points: item.history, currency: assetCurrency),
          const SizedBox(height: 22),
        ],
        Text('Prices', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        _Line('Market price', _money(item.marketPrice, assetCurrency)),
        _Line(
          'Average purchase price',
          _money(item.averagePrice, assetCurrency),
        ),
        _Line('Minimum price', _money(item.marketPriceMin, assetCurrency)),
        _Line('Maximum price', _money(item.marketPriceMax, assetCurrency)),
        const Divider(height: 30),
        Text(
          'Investment and returns',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        _Line('Quantity', _quantity(item.quantity)),
        _Line(
          'Invested incl. FX',
          _money(
            item.investmentInBaseCurrencyWithCurrencyEffect,
            widget.baseCurrency,
          ),
        ),
        _Line(
          'Net performance',
          _money(item.netPerformance, widget.baseCurrency),
        ),
        _Line(
          'Net performance incl. FX',
          _money(item.netPerformanceWithCurrencyEffect, widget.baseCurrency),
        ),
        _Line(
          'Return incl. FX',
          _percent(item.netPerformancePercentWithCurrencyEffect),
        ),
        _Line('Fees', _money(item.feeInBaseCurrency, widget.baseCurrency)),
        _Line(
          'Dividends',
          _money(item.dividendInBaseCurrency, widget.baseCurrency),
        ),
        _Line(
          'Dividend yield incl. FX',
          _percent(item.dividendYieldPercentWithCurrencyEffect),
        ),
      ],
    );
  }

  Widget _assetTab(HoldingDetailData item) {
    return ListView(
      key: const ValueKey('holding-asset-tab'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        Text(
          'Asset information',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text('Name', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          widget.holding.name,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Divider(height: 24),
        _Line('Symbol', widget.holding.symbol),
        _Line('ISIN', item.isin ?? 'Not available'),
        _Line('Asset currency', item.assetCurrency ?? 'Not available'),
        _Line('Asset class', item.assetClass ?? 'Not available'),
        _Line('Asset subclass', item.assetSubClass ?? 'Not available'),
        _Line(
          'Data source',
          item.dataSource ?? widget.holding.dataSource ?? 'Not available',
        ),
        const Divider(height: 30),
        Text('Activity summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        _Line(
          'First activity',
          item.dateOfFirstActivity == null
              ? 'Not available'
              : _date(item.dateOfFirstActivity!),
        ),
        _Line(
          'Transactions',
          item.activitiesCount?.toString() ?? 'Not available',
        ),
      ],
    );
  }
}

/// Retains downloaded transactions when moving between detail tabs.
class _ActivityTab extends StatefulWidget {
  const _ActivityTab({
    required this.enabled,
    required this.serverUrl,
    required this.jwt,
    required this.dataSource,
    required this.symbol,
    required this.client,
  });

  final bool enabled;
  final String serverUrl;
  final String jwt;
  final String? dataSource;
  final String symbol;
  final PortfolioClient? client;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.enabled) {
      return const Center(child: Text('Open Activity to load transactions.'));
    }
    if (widget.dataSource == null || widget.dataSource!.isEmpty) {
      return const Center(
        child: Text('Transactions are unavailable for this asset.'),
      );
    }
    return ListView(
      key: const ValueKey('holding-activity-tab'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        HoldingTransactions(
          serverUrl: widget.serverUrl,
          jwt: widget.jwt,
          dataSource: widget.dataSource!,
          symbol: widget.symbol,
          client: widget.client,
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.value,
    required this.allocation,
    required this.performance,
  });

  final String value;
  final String allocation;
  final String performance;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Value', value),
      ('Allocation', allocation),
      ('Return', performance),
    ];

    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;

        Widget metric(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              if (stacked)
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
            ],
          ),
        );

        return Card(
          key: const ValueKey('holding-summary-strip'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: stacked
                ? Column(
                    children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        metric(metrics[i].$1, metrics[i].$2),
                      ],
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < metrics.length; i++) ...[
                          if (i > 0)
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: scheme.outlineVariant,
                            ),
                          Expanded(child: metric(metrics[i].$1, metrics[i].$2)),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 158,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
  );
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _money(double? number, String currency) => number == null
    ? 'Not available'
    : '${number.toStringAsFixed(2)}${currency.isEmpty ? '' : ' $currency'}';

String _percent(double? number) =>
    number == null ? 'Not available' : '${(number * 100).toStringAsFixed(2)}%';

String _quantity(double? number) =>
    number == null ? 'Not available' : number.toStringAsFixed(4);
