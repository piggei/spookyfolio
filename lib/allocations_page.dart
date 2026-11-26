import 'package:material_ui/material_ui.dart';

import 'portfolio_client.dart';
import 'portfolio_allocations.dart';
import 'allocation_chart.dart';
import 'allocation_world_map.dart';

/// The shell owns the request and account/session context; the page only renders
/// Phase 1 aggregates and retains scroll/inspection state during navigation.
class AllocationsPage extends StatelessWidget {
  const AllocationsPage({
    super.key,
    required this.future,
    required this.baseCurrency,
    required this.contextRevision,
    required this.onRetry,
    this.accountName,
  });
  final Future<PortfolioSnapshot> future;
  final String? baseCurrency;
  final String? accountName;
  final Object contextRevision;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<PortfolioSnapshot>(
    key: ValueKey(contextRevision),
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          key: ValueKey('allocations-loading'),
          child: CircularProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                const Text('Could not load allocations.'),
                const SizedBox(height: 8),
                Text(
                  snapshot.error is PortfolioApiException
                      ? (snapshot.error! as PortfolioApiException).message
                      : 'Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      return AllocationsContent(
        snapshot: snapshot.requireData,
        baseCurrency: baseCurrency,
        accountName: accountName,
      );
    },
  );
}

class AllocationsContent extends StatefulWidget {
  const AllocationsContent({
    super.key,
    required this.snapshot,
    required this.baseCurrency,
    this.accountName,
  });
  final PortfolioSnapshot snapshot;
  final String? baseCurrency;
  final String? accountName;

  @override
  State<AllocationsContent> createState() => _AllocationsContentState();
}

class _AllocationsContentState extends State<AllocationsContent> {
  late PortfolioAllocations _data;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant AllocationsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot) ||
        oldWidget.baseCurrency != widget.baseCurrency) {
      _prepare();
    }
  }

  void _prepare() {
    // Choose one unit for the entire page. Restricted fractions never stand in
    // for missing monetary values inside an otherwise monetary chart.
    final hasMoney =
        widget.snapshot.holdings.any((holding) => holding.value != null) ||
        (widget.snapshot.accounts?.values.any(
              (account) => account.valueInBaseCurrency != null,
            ) ??
            false) ||
        (widget.snapshot.platforms?.values.any(
              (platform) => platform.valueInBaseCurrency != null,
            ) ??
            false) ||
        (widget.snapshot.markets?.values.any(
              (market) => market.valueInBaseCurrency != null,
            ) ??
            false) ||
        (widget.snapshot.marketsAdvanced?.values.any(
              (market) => market.valueInBaseCurrency != null,
            ) ??
            false) ||
        widget.snapshot.holdings.any(
          (holding) =>
              holding.assetProfile?.holdings?.any(
                (underlying) => underlying.valueInBaseCurrency != null,
              ) ??
              false,
        );
    final hasFractions =
        widget.snapshot.holdings.any(
          (holding) =>
              holding.valueInPercentage != null || holding.allocation != null,
        ) ||
        (widget.snapshot.accounts?.values.any(
              (account) => account.valueInPercentage != null,
            ) ??
            false) ||
        (widget.snapshot.markets?.values.any(
              (market) => market.valueInPercentage != null,
            ) ??
            false) ||
        (widget.snapshot.platforms?.values.any(
              (platform) => platform.valueInPercentage != null,
            ) ??
            false) ||
        (widget.snapshot.marketsAdvanced?.values.any(
              (market) => market.valueInPercentage != null,
            ) ??
            false);
    final unit = !hasMoney && hasFractions
        ? AllocationUnit.fraction
        : AllocationUnit.baseCurrency;
    _data = PortfolioAllocations.fromSnapshot(
      widget.snapshot,
      unit: unit,
      baseCurrency: widget.baseCurrency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final unit = data.byHolding.unit;
    final snapshot = widget.snapshot;
    final baseCurrency = widget.baseCurrency;
    final accountName = widget.accountName;
    Widget chart(String id, String title, AllocationBreakdown breakdown) =>
        AllocationChart(
          key: ValueKey('allocation-chart-$id'),
          id: id,
          title: title,
          data: breakdown,
          currency: baseCurrency,
        );
    return ListView(
      key: const PageStorageKey('allocations-page'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Allocations', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(accountName == null ? 'All accounts' : 'Account: $accountName'),
        if (unit == AllocationUnit.fraction)
          const Text('Percentage-only data · monetary values unavailable'),
        if (snapshot.hasError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ghostfolio reports incomplete portfolio data.'),
          ),
        if (snapshot.holdings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No holdings available for allocation analysis.'),
          ),
        const SizedBox(height: 16),
        AllocationPanel(
          id: 'net-worth',
          title: 'Proportion of Net Worth',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                allocationValue(
                  data.proportionOfNetWorth,
                  AllocationUnit.fraction,
                  null,
                ),
                key: const ValueKey('net-worth-proportion'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (data.proportionOfNetWorth == null) ...[
                const SizedBox(height: 6),
                const Text('The server has not supplied this proportion.'),
              ],
            ],
          ),
        ),
        chart('platform', 'By Platform', data.byPlatform),
        chart('currency', 'By Currency', data.byCurrency),
        chart('asset-class', 'By Asset Class', data.byAssetClass),
        chart('holding', 'By Holding', data.byHolding),
        chart('sector', 'By Sector', data.bySector),
        chart('continent', 'By Continent', data.byContinent),
        chart('market', 'By Market', data.byMarket),
        AllocationPanel(
          id: 'regions',
          title: 'Regions / World Map',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AllocationWorldMap(data: data.worldMap, currency: baseCurrency),
              const SizedBox(height: 12),
              const Text(
                'Regional classification',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              if (data.regions.total != null)
                Text(
                  'Regional total: ${allocationValue(data.regions.total, unit, baseCurrency)}',
                ),
              if (data.regions.hasUnavailableValues && data.regions.isAvailable)
                const Text('Some regional values are unavailable.'),
              for (final bucket in data.regions.buckets)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${allocationLabel(bucket)}: ${allocationValue(bucket.value, unit, baseCurrency)}',
                  ),
                ),
              if (!data.regions.isAvailable)
                const Text('Regional classification is unavailable.'),
            ],
          ),
        ),
        chart('country', 'By Country', data.byCountry),
        chart('account', 'By Account', data.byAccount),
        chart('etf-provider', 'By ETF Provider', data.byEtfProvider),
        _EtfHoldings(data: data.byEtfHolding, currency: baseCurrency),
      ],
    );
  }
}

class _EtfHoldings extends StatefulWidget {
  const _EtfHoldings({required this.data, required this.currency});
  final EtfHoldingAnalysis data;
  final String? currency;
  @override
  State<_EtfHoldings> createState() => _EtfHoldingsState();
}

class _EtfHoldingsState extends State<_EtfHoldings> {
  bool _showAll = false;
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final shown = _showAll ? data.holdings : data.holdings.take(5);
    return AllocationPanel(
      id: 'etf-holding',
      title: 'By ETF Holding',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Experimental · Approximate',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 8),
          Text(
            'Funds with available composition: ${allocationValue(data.coveredFundValue, data.unit, widget.currency)}',
          ),
          if (data.positionsWithoutComposition.isNotEmpty)
            ExpansionTile(
              key: const PageStorageKey('etf-missing-composition'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Missing composition (${data.positionsWithoutComposition.length})',
              ),
              children: [
                for (final id in data.positionsWithoutComposition)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(id),
                  ),
              ],
            ),
          if (data.holdings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No ETF underlying holdings available.'),
            ),
          for (final holding in shown)
            ExpansionTile(
              key: PageStorageKey('etf-holding-${holding.name}'),
              tilePadding: EdgeInsets.zero,
              title: Text(holding.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allocationValue(holding.value, data.unit, widget.currency),
                  ),
                  Text(
                    '${allocationValue(holding.allocationInPercentage, AllocationUnit.fraction, null)} ${data.unit == AllocationUnit.fraction ? 'of portfolio' : 'of funds with available composition'}',
                  ),
                ],
              ),
              children: [
                for (final parent in holding.parents)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${parent.name} · ${parent.symbol}'),
                        Text(
                          allocationValue(
                            parent.value,
                            data.unit,
                            widget.currency,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (data.holdings.length > 5)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll
                    ? 'Show fewer holdings'
                    : 'Show all ${data.holdings.length} underlying holdings',
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Up to 50 underlying holdings are shown; ETF composition may be partial.',
          ),
        ],
      ),
    );
  }
}
