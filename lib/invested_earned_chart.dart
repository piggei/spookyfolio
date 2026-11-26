import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'portfolio_client.dart';
import 'portfolio_evolution.dart';

/// Only the explicit server monetary channels are plotted, in base currency.
class InteractiveInvestedEarnedChart extends StatefulWidget {
  const InteractiveInvestedEarnedChart({
    super.key,
    required this.history,
    required this.baseCurrency,
    this.contextRevision,
  });

  final PortfolioHistory history;
  final String? baseCurrency;
  final Object? contextRevision;

  @override
  State<InteractiveInvestedEarnedChart> createState() =>
      _InteractiveInvestedEarnedChartState();
}

class _InteractiveInvestedEarnedChartState
    extends State<InteractiveInvestedEarnedChart> {
  late PortfolioEvolution _evolution;
  late List<PortfolioEvolutionPoint> _points;
  int? _selected;

  void _readHistory() {
    _evolution = PortfolioEvolution.fromHistory(
      widget.history,
      baseCurrency: widget.baseCurrency,
    );
    _points = [..._evolution.points]..sort((a, b) => a.date.compareTo(b.date));
    _selected = null;
  }

  @override
  void initState() {
    super.initState();
    _readHistory();
  }

  @override
  void didUpdateWidget(covariant InteractiveInvestedEarnedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.history, oldWidget.history) ||
        widget.baseCurrency != oldWidget.baseCurrency ||
        widget.contextRevision != oldWidget.contextRevision) {
      _readHistory();
    }
  }

  void _select(double x, double width) {
    if (_points.isEmpty) return;
    final fraction = ((x - _inset) / math.max(1, width - 2 * _inset)).clamp(
      0.0,
      1.0,
    );
    var closest = 0;
    var distance = double.infinity;
    for (var i = 0; i < _points.length; i++) {
      final candidate = (_position(_points, i) - fraction).abs();
      if (candidate < distance) {
        closest = i;
        distance = candidate;
      }
    }
    setState(() => _selected = closest);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = _evolution.baseCurrency;
    final validCurrency =
        currency != null && RegExp(r'^[A-Z]{3}$').hasMatch(currency);
    final hasMoney = _points.any(
      (p) => p.investedCapital != null || p.portfolioValue != null,
    );
    final selected = _points.isEmpty
        ? null
        : _points[_selected ?? _points.length - 1];
    String money(double? value) => value == null
        ? 'Not available'
        : '${value.toStringAsFixed(2)} ${validCurrency ? currency : '(currency unavailable)'}';

    Widget legend(String label, Color color, IconData icon) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            legend('Invested Capital', scheme.primary, Icons.circle),
            legend('Portfolio Value', scheme.tertiary, Icons.square),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          validCurrency
              ? 'Base currency: $currency'
              : 'Base currency unavailable',
        ),
        if (_evolution.hasErrors)
          const Text('The server reports incomplete historical data.'),
        if (_points.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('No historical monetary data for this period'),
          )
        else ...[
          if (!hasMoney)
            const Text(
              'Historical monetary values unavailable. Access or subscription may restrict this data.',
            )
          else if (!_evolution.hasCompleteMonetarySeries)
            const Text(
              'Some monetary values are unavailable. Gaps are not connected.',
            ),
          LayoutBuilder(
            builder: (context, constraints) => Semantics(
              label: 'Invested Capital and Portfolio Value by date. Tap or drag to select a date.',
              child: GestureDetector(
                key: const ValueKey('invested-earned-plot'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _select(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragStart: (d) =>
                    _select(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    _select(d.localPosition.dx, constraints.maxWidth),
                child: SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: _MonetaryPainter(
                      points: _points,
                      selected: _selected ?? _points.length - 1,
                      investedColor: scheme.primary,
                      valueColor: scheme.tertiary,
                      gridColor: scheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(_date(_points.first.date)),
              if (_points.length > 1) Text(_date(_points.last.date)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Tap or drag the chart to select a date'),
          Text(
            _date(selected!.date),
            key: const ValueKey('evolution-selected-date'),
          ),
          Text(
            'Invested Capital: ${money(selected.investedCapital)}',
            key: const ValueKey('evolution-selected-invested'),
          ),
          Text(
            'Portfolio Value: ${money(selected.portfolioValue)}',
            key: const ValueKey('evolution-selected-value'),
          ),
        ],
      ],
    );
  }
}

const _inset = 12.0;

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

double _position(List<PortfolioEvolutionPoint> points, int index) {
  if (points.length == 1) return 0.5;
  final first = points.first.date.millisecondsSinceEpoch;
  final duration = points.last.date.millisecondsSinceEpoch - first;
  return duration == 0
      ? index / (points.length - 1)
      : (points[index].date.millisecondsSinceEpoch - first) / duration;
}

class _MonetaryPainter extends CustomPainter {
  const _MonetaryPainter({
    required this.points,
    required this.selected,
    required this.investedColor,
    required this.valueColor,
    required this.gridColor,
  });

  final List<PortfolioEvolutionPoint> points;
  final int selected;
  final Color investedColor;
  final Color valueColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 * _inset) return;
    final values = [
      for (final p in points) ...[?p.investedCapital, ?p.portfolioValue],
    ];
    if (values.isEmpty) return;
    // Scale before finding bounds so even extreme finite monetary values cannot
    // overflow the chart geometry. Original amounts are retained for inspection.
    final scale = math.max(1.0, values.map((v) => v.abs()).reduce(math.max));
    final low = math.min(0.0, values.reduce(math.min) / scale);
    final high = math.max(0.0, values.reduce(math.max) / scale);
    final span = high == low ? 1.0 : high - low;
    final plotHeight = size.height - 2 * _inset;
    double x(int i) =>
        _inset + (size.width - 2 * _inset) * _position(points, i);
    double y(double v) =>
        _inset + plotHeight * (0.05 + 0.9 * (high - v / scale) / span);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final yy = _inset + plotHeight * i / 4;
      canvas.drawLine(
        Offset(_inset, yy),
        Offset(size.width - _inset, yy),
        grid,
      );
    }
    canvas.drawLine(
      Offset(x(selected), _inset),
      Offset(x(selected), size.height - _inset),
      grid,
    );

    void series(
      double? Function(PortfolioEvolutionPoint) amount,
      Color color, {
      required bool square,
    }) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5;
      Offset? previous;
      for (var i = 0; i < points.length; i++) {
        final value = amount(points[i]);
        if (value == null) {
          previous = null;
          continue;
        }
        final current = Offset(x(i), y(value));
        if (previous != null) canvas.drawLine(previous, current, paint);
        // Draw markers only for the selected observation.
        // Long histories must remain readable without thousands of symbols.
        if (i == selected) {
          const radius = 5.0;
          if (square) {
            canvas.drawRect(
              Rect.fromCircle(center: current, radius: radius),
              paint,
            );
          } else {
            canvas.drawCircle(current, radius, paint);
          }
        }
        previous = current;
      }
    }

    series((p) => p.investedCapital, investedColor, square: false);
    series((p) => p.portfolioValue, valueColor, square: true);
  }

  @override
  bool shouldRepaint(covariant _MonetaryPainter oldDelegate) =>
      points != oldDelegate.points ||
      selected != oldDelegate.selected ||
      investedColor != oldDelegate.investedColor ||
      valueColor != oldDelegate.valueColor ||
      gridColor != oldDelegate.gridColor;
}
