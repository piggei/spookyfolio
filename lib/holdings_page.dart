import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'holding_detail.dart';
import 'portfolio_client.dart';

/// All data here come from the already-loaded portfolio details response.
class HoldingsPage extends StatelessWidget {
  const HoldingsPage({
    super.key,
    required this.holdings,
    required this.baseCurrency,
    required this.serverUrl,
    required this.jwt,
    this.accountFiltered = false,
    this.client,
  });

  final List<PortfolioHolding> holdings;
  final String baseCurrency;
  final String serverUrl;
  final String jwt;
  final bool accountFiltered;
  final PortfolioClient? client;

  @override
  Widget build(BuildContext context) {
    final sorted = [...holdings]
      ..sort((a, b) => (b.allocation ?? -1).compareTo(a.allocation ?? -1));
    return ListView(
      key: const ValueKey('holdings-page'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Holdings (${sorted.length})',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (accountFiltered)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Asset detail is portfolio-wide and unavailable in account view.',
            ),
          ),
        if (sorted.isEmpty)
          const Text('No holdings yet. Add transactions in Ghostfolio.'),
        for (final holding in sorted)
          Card(
            child: ListTile(
              key: ValueKey('holding-${holding.symbol}'),
              title: Text(holding.name),
              subtitle: Text(
                '${holding.symbol}  ·  ${_percent(holding.allocation)} allocation',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(holding.value, baseCurrency)),
                      Text(
                        _percent(holding.netPerformancePercent),
                        style: TextStyle(
                          color: holdingReturnColor(
                            Theme.of(context).colorScheme,
                            holding.netPerformancePercent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: accountFiltered
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HoldingDetailPage(
                          holding: holding,
                          baseCurrency: baseCurrency,
                          serverUrl: serverUrl,
                          jwt: jwt,
                          client: client,
                        ),
                      ),
                    ),
            ),
          ),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Allocation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          AllocationDonut(holdings: sorted),
        ],
      ],
    );
  }
}

class AllocationDonut extends StatelessWidget {
  const AllocationDonut({super.key, required this.holdings});
  final List<PortfolioHolding> holdings;

  @override
  Widget build(BuildContext context) {
    final valid = holdings
        .where(
          (h) =>
              h.allocation != null &&
              h.allocation!.isFinite &&
              h.allocation! > 0,
        )
        .toList();
    final sum = valid.fold<double>(0, (total, h) => total + h.allocation!);
    // Ghostfolio returns fractions, not percentage points. Avoid distorting
    // allocations: we deliberately do not normalize to 100%.
    final complete =
        holdings.every((h) => h.allocation != null) &&
        sum >= 0.995 &&
        sum <= 1.005;
    if (valid.isEmpty || sum > 1.005) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text('Allocation data are not available or inconsistent.'),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    // Stable per-asset colors. Cash is neutral; non-cash positions use
    // distinct high-contrast hues, independent of the display sort order.
    final palette = <Color>[
      const Color(0xFF8B5CF6), // violet
      const Color(0xFFF59E0B), // amber
      const Color(0xFF0891B2), // teal-blue
      const Color(0xFFE87986), // coral
      const Color(0xFF65A30D), // olive
      const Color(0xFF2563EB), // blue
      const Color(0xFFD946EF), // magenta
      const Color(0xFFB45309), // brown
    ];
    final assetKeys =
        valid
            .where(
              (h) =>
                  !(h.symbol == h.name &&
                      RegExp(r'^[A-Z]{3}$').hasMatch(h.symbol)),
            )
            .map((h) => '${h.dataSource ?? ''}:${h.symbol}')
            .toSet()
            .toList()
          ..sort();
    final assigned = <String, Color>{};
    final occupied = <int>{};
    for (final key in assetKeys) {
      var hash = 0;
      for (final code in key.codeUnits) {
        hash = (hash * 31 + code) & 0x7fffffff;
      }
      var index = hash % palette.length;
      while (occupied.contains(index) && occupied.length < palette.length) {
        index = (index + 1) % palette.length;
      }
      occupied.add(index);
      assigned[key] = palette[index];
    }
    final cashColor = scheme.brightness == Brightness.dark
        ? const Color(0xFF8F98A7)
        : const Color(0xFF64748B);
    final colors = <Color>[
      for (final holding in valid)
        holding.symbol == holding.name &&
                RegExp(r'^[A-Z]{3}$').hasMatch(holding.symbol)
            ? cashColor
            : assigned['${holding.dataSource ?? ''}:${holding.symbol}'] ??
                  scheme.primary,
    ];
    return Column(
      children: [
        Semantics(
          label: 'Portfolio allocation chart',
          child: SizedBox(
            width: 214,
            height: 214,
            child: CustomPaint(
              painter: _DonutPainter(
                values: valid.map((h) => h.allocation!).toList(),
                colors: colors,
                remainder: math.max(0, 1 - sum),
                remainderColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < valid.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    valid[i].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_percent(valid[i].allocation)),
              ],
            ),
          ),
        if (!complete) ...[
          const SizedBox(height: 10),
          Text(
            'Allocation is incomplete: the chart only shows percentages provided by Ghostfolio.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.remainder,
    required this.remainderColor,
  });

  final List<double> values;
  final List<Color> colors;
  final double remainder;
  final Color remainderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.40;
    final stroke = math.min(size.width, size.height) * 0.15;
    final rect = Rect.fromCircle(center: center, radius: radius);
    double angle = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.max(0, values[i]) * 2 * math.pi;
      if (sweep <= 0) continue;
      // Thin transparent separators improve adjacent-color recognition.
      final gap = math.min(0.012, sweep * 0.20);
      paint.color = colors[i];
      canvas.drawArc(
        rect,
        angle + gap / 2,
        math.max(0, sweep - gap),
        false,
        paint,
      );
      angle += sweep;
    }
    if (remainder > 0.000001) {
      paint.color = remainderColor;
      canvas.drawArc(rect, angle, remainder * 2 * math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      !identical(oldDelegate.values, values) ||
      oldDelegate.colors != colors ||
      oldDelegate.remainder != remainder ||
      oldDelegate.remainderColor != remainderColor;
}

String _money(double? number, String currency) => number == null
    ? 'Not available'
    : '${number.toStringAsFixed(2)}${currency.isEmpty ? '' : ' $currency'}';

String _percent(double? number) =>
    number == null ? 'Not available' : '${(number * 100).toStringAsFixed(2)}%';

/// Green for gains, red for losses, neutral foreground for zero or missing.
Color holdingReturnColor(ColorScheme scheme, double? percent) {
  if (percent == null || !percent.isFinite || percent == 0) {
    return scheme.onSurface;
  }
  if (percent > 0) {
    return scheme.brightness == Brightness.dark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
  }
  return scheme.brightness == Brightness.dark
      ? const Color(0xFFEF9A9A)
      : const Color(0xFFC62828);
}
