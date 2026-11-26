import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show listEquals;

import 'portfolio_allocations.dart';

String allocationValue(double? value, AllocationUnit unit, String? currency) {
  if (value == null) return 'Unavailable';
  if (unit == AllocationUnit.fraction) {
    return '${(value * 100).toStringAsFixed(2)}%';
  }
  return '${value.toStringAsFixed(2)} ${currency == null || currency.isEmpty ? '(currency unavailable)' : currency}';
}

String allocationLabel(AllocationBucket bucket) => switch (bucket.label) {
  unknownAllocation => 'Unknown / unclassified',
  'developedMarkets' => 'Developed markets',
  'emergingMarkets' => 'Emerging markets',
  'otherMarkets' => 'Other markets',
  'asiaPacific' => 'Asia-Pacific',
  'northAmerica' => 'North America',
  'europe' => 'Europe',
  'japan' => 'Japan',
  _ => bucket.label,
};

class AllocationPanel extends StatelessWidget {
  const AllocationPanel({
    super.key,
    required this.id,
    required this.title,
    required this.child,
  });
  final String id;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('allocation-card-$id'),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

/// Classification completeness is independent of whether a numeric sum exists.
class AllocationStatus extends StatelessWidget {
  const AllocationStatus({
    super.key,
    required this.data,
    required this.currency,
  });
  final AllocationBreakdown data;
  final String? currency;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!data.isAvailable)
        const Text('This breakdown is unavailable from the server.')
      else ...[
        if (data.hasIncompleteClassifications)
          const Text(
            'Incomplete or overlapping classification weights. A complete total is unavailable.',
          ),
        if (data.hasUnavailableValues)
          const Text(
            'Some category values are unavailable. Missing values are not counted as zero.',
          ),
        if (data.buckets.isNotEmpty && data.total != null)
          Text(
            'Total exposure: ${allocationValue(data.total, data.unit, currency)}',
          ),
        if (data.hasIncompleteClassifications && data.bucketTotal != null)
          Text(
            'Displayed bucket sum: ${allocationValue(data.bucketTotal, data.unit, currency)}. This is not a complete allocation.',
          ),
      ],
    ],
  );
}

/// Donut slices show proportions only when a reliable positive total exists.
/// Incomplete or unavailable distributions retain an inspectable legend without
/// manufacturing a 100% allocation.
class AllocationChart extends StatefulWidget {
  const AllocationChart({
    super.key,
    required this.id,
    required this.title,
    required this.data,
    required this.currency,
  });
  final String id;
  final String title;
  final AllocationBreakdown data;
  final String? currency;
  @override
  State<AllocationChart> createState() => _AllocationChartState();
}

class _AllocationChartState extends State<AllocationChart> {
  bool _showAll = false;

  Future<void> _inspect(AllocationBucket bucket) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              allocationLabel(bucket),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SelectableText(
              allocationValue(bucket.value, widget.data.unit, widget.currency),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('Identifier: ${bucket.id}'),
            if (bucket.dataSources.isNotEmpty)
              Text('Data sources: ${bucket.dataSources.join(', ')}'),
            if (bucket.dataSources.length > 1)
              const Text(
                'Combined exposure for this exact symbol across data sources.',
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _entry(AllocationBucket bucket, {bool nested = false}) {
    final color = _bucketColor(Theme.of(context).colorScheme, bucket);
    final description =
        '${allocationLabel(bucket)}, ${allocationValue(bucket.value, widget.data.unit, widget.currency)}';
    return Padding(
      padding: EdgeInsets.only(left: nested ? 16 : 0, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: description,
            excludeSemantics: true,
            onTap: () => _inspect(bucket),
            child: InkWell(
              key: ValueKey('allocation-row-${widget.id}-${bucket.id}'),
              onTap: () => _inspect(bucket),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5, right: 8),
                          child: Icon(Icons.circle, size: 10, color: color),
                        ),
                        Expanded(
                          child: Text(
                            allocationLabel(bucket),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, size: 16),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 18,
                        top: 2,
                        bottom: 6,
                      ),
                      child: Text(
                        allocationValue(
                          bucket.value,
                          widget.data.unit,
                          widget.currency,
                        ),
                        key: ValueKey(
                          'allocation-value-${widget.id}-${bucket.id}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (bucket.children.isNotEmpty)
            ExpansionTile(
              key: PageStorageKey(
                'allocation-subclasses-${widget.id}-${bucket.id}',
              ),
              title: Text('Subclasses (${bucket.children.length})'),
              tilePadding: const EdgeInsets.only(left: 16),
              children: [
                for (final child in bucket.children)
                  _entry(child, nested: true),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final shown = _showAll ? data.buckets : data.buckets.take(5);
    return AllocationPanel(
      id: widget.id,
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.basis != AllocationBasis.portfolio) ...[
            Text(switch (data.basis) {
              AllocationBasis.nonCashHoldings => 'Excludes cash',
              AllocationBasis.serverMarkets =>
                'Server-reported market classification',
              AllocationBasis.fundsWithComposition =>
                'Funds with available composition',
              AllocationBasis.portfolio => '',
            }, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
          ],
          // A quantified Unknown slice already explains a complete donut.
          // Retain diagnostics only for genuinely unavailable/inconsistent data.
          if (!((widget.id == 'sector' || widget.id == 'continent') &&
              data.isAvailable &&
              data.total != null &&
              !data.hasIncompleteClassifications &&
              !data.hasUnavailableValues))
            AllocationStatus(data: data, currency: widget.currency),
          if (data.isAvailable && data.buckets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No allocation data.'),
            ),
          if (data.isAvailable && data.buckets.isNotEmpty)
            _DonutChart(
              data: data,
              colorFor: (bucket) =>
                  _bucketColor(Theme.of(context).colorScheme, bucket),
            ),
          for (final bucket in shown) _entry(bucket),
          if (data.buckets.length > 5)
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll
                    ? 'Show fewer categories'
                    : 'Show all ${data.buckets.length} categories',
              ),
            ),
        ],
      ),
    );
  }
}

Color _bucketColor(ColorScheme scheme, AllocationBucket bucket) {
  if (bucket.id == unknownAllocation) return scheme.outline;
  if (bucket.value != null && bucket.value! < 0) return scheme.error;
  var hash = 0;
  for (final code in bucket.id.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  // Match the distinct, high-contrast hues already used by Holdings.
  const palette = <Color>[
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF0891B2),
    Color(0xFFE87986),
    Color(0xFF65A30D),
    Color(0xFF2563EB),
    Color(0xFFD946EF),
    Color(0xFFB45309),
  ];
  return palette[hash % palette.length];
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.data, required this.colorFor});
  final AllocationBreakdown data;
  final Color Function(AllocationBucket) colorFor;

  @override
  Widget build(BuildContext context) {
    final total = data.total;
    // A donut is a part-to-whole chart. Null values, incomplete weights,
    // non-positive totals or negative components do not define a reliable whole.
    final canDraw =
        data.isAvailable &&
        !data.hasIncompleteClassifications &&
        !data.hasUnavailableValues &&
        total != null &&
        total.isFinite &&
        total > 0 &&
        (data.unit != AllocationUnit.fraction || (total - 1).abs() < 1e-6) &&
        data.buckets.every((b) => b.value != null && b.value! >= 0);
    if (!canDraw) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'A complete proportional chart is unavailable; inspect the category values below.',
        ),
      );
    }
    final parts = data.buckets.where((b) => b.value! > 0).toList();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox.square(
          dimension: 174,
          child: Semantics(
            label: 'Allocation donut chart. Category values are listed below.',
            image: true,
            child: CustomPaint(
              key: const ValueKey('allocation-donut'),
              painter: _DonutPainter(
                parts: parts,
                total: total,
                colors: parts.map(colorFor).toList(),
                trackColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.parts,
    required this.total,
    required this.colors,
    required this.trackColor,
  });
  final List<AllocationBucket> parts;
  final double total;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .39;
    final stroke = math.min(size.width, size.height) * .16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = trackColor);
    var start = -math.pi / 2;
    for (var i = 0; i < parts.length; i++) {
      final sweep = 2 * math.pi * (parts[i].value! / total);
      if (!sweep.isFinite || sweep <= 0) continue;
      canvas.drawArc(rect, start, sweep, false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total ||
      old.trackColor != trackColor ||
      !listEquals(old.parts, parts) ||
      !listEquals(old.colors, colors);
}
