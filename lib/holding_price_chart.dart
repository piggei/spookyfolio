import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'holding_detail_data.dart';

/// Displays the API's price and historical average-cost series in asset currency.
/// Missing points are gaps, not zero prices. No investment formulas are applied.
class HoldingPriceChart extends StatefulWidget {
  const HoldingPriceChart({
    super.key,
    required this.points,
    required this.currency,
  });

  final List<HoldingPricePoint> points;
  final String currency;

  @override
  State<HoldingPriceChart> createState() => _HoldingPriceChartState();
}

class _HoldingPriceChartState extends State<HoldingPriceChart> {
  int? selectedIndex;

  @override
  void didUpdateWidget(covariant HoldingPriceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) selectedIndex = null;
  }

  void selectAt(double dx, double totalWidth, List<HoldingPricePoint> points) {
    if (points.isEmpty) return;
    final width = math.max(1.0, totalWidth - 60 - 12);
    final fraction = ((dx - 60) / width).clamp(0.0, 1.0);
    final start = points.first.date.millisecondsSinceEpoch;
    final span = points.last.date.millisecondsSinceEpoch - start;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final x = span == 0
          ? i / math.max(1, points.length - 1)
          : (points[i].date.millisecondsSinceEpoch - start) / span;
      if ((x - fraction).abs() < bestDistance) {
        bestDistance = (x - fraction).abs();
        best = i;
      }
    }
    if (selectedIndex != best) setState(() => selectedIndex = best);
  }

  @override
  Widget build(BuildContext context) {
    final points = [...widget.points]..sort((a, b) => a.date.compareTo(b.date));
    final visible = points
        .where((p) => p.marketPrice != null || p.averagePrice != null)
        .toList();
    if (visible.length < 2) {
      return const Text('Historical price data are not available.');
    }
    final scheme = Theme.of(context).colorScheme;
    final marketColor = scheme.primary;
    final costColor = scheme.brightness == Brightness.dark
        ? const Color(0xFFFFC069)
        : const Color(0xFF9E5800);
    final selected = selectedIndex != null && selectedIndex! < visible.length
        ? visible[selectedIndex!]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Legend(color: marketColor, label: 'Market price'),
            const SizedBox(width: 18),
            _Legend(color: costColor, label: 'Average cost'),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 218,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (event) => selectAt(
                event.localPosition.dx,
                constraints.maxWidth,
                visible,
              ),
              onHorizontalDragStart: (event) => selectAt(
                event.localPosition.dx,
                constraints.maxWidth,
                visible,
              ),
              onHorizontalDragUpdate: (event) => selectAt(
                event.localPosition.dx,
                constraints.maxWidth,
                visible,
              ),
              child: CustomPaint(
                painter: _PricePainter(
                  points: visible,
                  selectedIndex: selectedIndex,
                  marketColor: marketColor,
                  costColor: costColor,
                  gridColor: scheme.outlineVariant,
                  labelColor: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (selected == null)
          Text(
            'Touch the chart to inspect prices',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          )
        else
          Text(
            '${_date(selected.date)}  ·  '
            'Market: ${_amount(selected.marketPrice, widget.currency)}  ·  '
            'Cost: ${_amount(selected.averagePrice, widget.currency)}',
            key: const ValueKey('holding-price-selected'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 18, height: 3, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _amount(double? value, String currency) =>
    value == null ? '—' : '${value.toStringAsFixed(2)} $currency';

class _PricePainter extends CustomPainter {
  const _PricePainter({
    required this.points,
    required this.selectedIndex,
    required this.marketColor,
    required this.costColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<HoldingPricePoint> points;
  final int? selectedIndex;
  final Color marketColor;
  final Color costColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 60.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 29.0;
    if (size.width <= left + right || size.height <= top + bottom) return;
    final values = <double>[
      for (final p in points) ...[
        if (p.marketPrice != null) p.marketPrice!,
        if (p.averagePrice != null) p.averagePrice!,
      ],
    ];
    if (values.isEmpty) return;
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final padding = math.max(0.01, (maximum - minimum) * 0.1);
    final low = minimum - padding;
    final high = maximum + padding;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    final start = points.first.date.millisecondsSinceEpoch;
    final span = points.last.date.millisecondsSinceEpoch - start;
    double x(int i) =>
        left +
        width *
            (span == 0
                ? i / math.max(1, points.length - 1)
                : (points[i].date.millisecondsSinceEpoch - start) / span);
    double y(double v) => top + height * (high - v) / (high - low);

    void label(String value, Offset offset, {bool rightAlign = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(rightAlign ? offset.dx - painter.width : offset.dx, offset.dy),
      );
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 4; i++) {
      final value = low + (high - low) * i / 4;
      final yy = y(value);
      canvas.drawLine(
        Offset(left, yy),
        Offset(size.width - right, yy),
        gridPaint,
      );
      label(value.toStringAsFixed(2), Offset(0, yy - 7));
    }
    label(_date(points.first.date), Offset(left, size.height - 14));
    label(
      _date(points.last.date),
      Offset(size.width - right, size.height - 14),
      rightAlign: true,
    );

    void drawSeries(double? Function(HoldingPricePoint) getValue, Color color) {
      final path = Path();
      var open = false;
      for (var i = 0; i < points.length; i++) {
        final value = getValue(points[i]);
        if (value == null) {
          open = false;
          continue;
        }
        if (!open) {
          path.moveTo(x(i), y(value));
          open = true;
        } else {
          path.lineTo(x(i), y(value));
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawSeries((p) => p.marketPrice, marketColor);
    drawSeries((p) => p.averagePrice, costColor);
    if (selectedIndex != null && selectedIndex! < points.length) {
      final xx = x(selectedIndex!);
      canvas.drawLine(
        Offset(xx, top),
        Offset(xx, top + height),
        Paint()
          ..color = labelColor.withValues(alpha: 0.65)
          ..strokeWidth = 1,
      );
      for (final (value, color) in [
        (points[selectedIndex!].marketPrice, marketColor),
        (points[selectedIndex!].averagePrice, costColor),
      ]) {
        if (value != null) {
          canvas.drawCircle(Offset(xx, y(value)), 4, Paint()..color = color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PricePainter old) =>
      !identical(old.points, points) ||
      old.selectedIndex != selectedIndex ||
      old.marketColor != marketColor ||
      old.costColor != costColor ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor;
}
