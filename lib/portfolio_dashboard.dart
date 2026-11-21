import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'portfolio_client.dart';

/// Read-only dashboard. Every financial figure comes from Ghostfolio APIs.
class PortfolioDashboard extends StatefulWidget {
  const PortfolioDashboard({
    super.key,
    required this.serverUrl,
    required this.jwt,
    this.client,
  });
  final String serverUrl;
  final String jwt;
  final PortfolioClient? client;

  @override
  State<PortfolioDashboard> createState() => _PortfolioDashboardState();
}

class _PortfolioDashboardState extends State<PortfolioDashboard> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PortfolioDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.jwt != widget.jwt) {
      _reload();
    }
  }

  void _reload() {
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final client = widget.client ?? PortfolioClient();
    final profile = await client.getProfile(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
    );
    final details = await client.getDetails(
      serverUrl: widget.serverUrl,
      jwt: widget.jwt,
    );
    PortfolioHistory? history;
    String? historyIssue;
    try {
      history = await client.getHistory(
        serverUrl: widget.serverUrl,
        jwt: widget.jwt,
      );
    } catch (error) {
      historyIssue = error is PortfolioApiException
          ? error.message
          : 'History unavailable';
    }
    return _DashboardData(profile, details, history, historyIssue);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is PortfolioApiException
              ? error.message
              : 'Could not load portfolio. Check the server and connection.';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }
        final data = snapshot.requireData;
        final currency = data.profile.baseCurrency ?? '';
        final summary = data.details;
        final holdings = [...summary.holdings]
          ..sort((a, b) => (b.allocation ?? -1).compareTo(a.allocation ?? -1));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Base currency: ${currency.isEmpty ? 'not specified' : currency}',
            ),
            if (summary.hasError) ...[
              const SizedBox(height: 8),
              const Text('Ghostfolio reported incomplete portfolio data.'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(
                  label: 'Portfolio value',
                  value: _money(data.history?.portfolioValue, currency),
                ),
                if (summary.netWorth != null)
                  _Metric(
                    label: 'Net worth',
                    value: _money(summary.netWorth, currency),
                  ),
                _Metric(
                  label: 'Invested',
                  value: _money(summary.investedValue, currency),
                ),
                _Metric(
                  label: 'Change incl. FX',
                  value: _money(
                    data.history?.changeWithCurrencyEffect,
                    currency,
                  ),
                ),
                if (summary.netPerformance != null)
                  _Metric(
                    label: 'Net performance',
                    value: _money(summary.netPerformance, currency),
                  ),
                _Metric(
                  label: 'Return',
                  value: _percentage(summary.netPerformancePercentage),
                ),
                _Metric(label: 'Cash', value: _money(summary.cash, currency)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Portfolio history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.historyIssue != null)
              Text(data.historyIssue!)
            else if (data.history == null ||
                data.history!.points
                        .where((p) => p.returnWithCurrencyEffect != null)
                        .length <
                    2)
              const Text('Not enough historical return data to draw a chart.')
            else ...[
              const Text('Return including currency effect'),
              const SizedBox(height: 8),
              SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HistoryPainter(data.history!.points),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Holdings (${holdings.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (holdings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No holdings yet. Add transactions in Ghostfolio to populate your portfolio.',
                ),
              ),
            for (final holding in holdings.take(15))
              Card(
                child: ListTile(
                  title: Text(holding.name),
                  subtitle: Text(
                    '${holding.symbol} · ${_percentage(holding.allocation)} allocation',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(holding.value, currency)),
                      Text(_percentage(holding.netPerformancePercent)),
                    ],
                  ),
                ),
              ),
            if (holdings.length > 15)
              Text('${holdings.length - 15} more holdings'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh data'),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData(
    this.profile,
    this.details,
    this.history,
    this.historyIssue,
  );
  final GhostfolioProfile profile;
  final PortfolioSnapshot details;
  final PortfolioHistory? history;
  final String? historyIssue;
}

String _money(double? value, String currency) {
  if (value == null) return 'Not available';
  return '${value.toStringAsFixed(2)}${currency.isEmpty ? '' : ' $currency'}';
}

// Ghostfolio percentage fields are ratios (e.g. 0.125 => 12.5%).
String _percentage(double? ratio) =>
    ratio == null ? 'Not available' : '${(ratio * 100).toStringAsFixed(2)}%';

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 154,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.points);
  final List<PortfolioPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values =
        points.where((p) => p.returnWithCurrencyEffect != null).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (values.length < 2) return;
    final minValue = values
        .map((p) => p.returnWithCurrencyEffect!)
        .reduce(math.min);
    final maxValue = values
        .map((p) => p.returnWithCurrencyEffect!)
        .reduce(math.max);
    final span = maxValue - minValue;
    final first = values.first.date.millisecondsSinceEpoch;
    final last = values.last.date.millisecondsSinceEpoch;
    final timeSpan = last - first;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = values[i];
      final x = timeSpan == 0
          ? size.width * i / (values.length - 1)
          : size.width * (point.date.millisecondsSinceEpoch - first) / timeSpan;
      final y = span == 0
          ? size.height / 2
          : size.height *
                (1 - (point.returnWithCurrencyEffect! - minValue) / span);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB68AF7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) =>
      oldDelegate.points != points;
}
