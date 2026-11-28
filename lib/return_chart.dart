import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'portfolio_client.dart';

/// Renders the API's relative return series; never derives a new return metric.
class InteractiveReturnChart extends StatefulWidget {
  const InteractiveReturnChart({super.key, required this.points});

  final List<PortfolioPoint> points;

  @override
  State<InteractiveReturnChart> createState() => _InteractiveReturnChartState();
}

class _InteractiveReturnChartState extends State<InteractiveReturnChart> {
  static const _left = 56.0;
  static const _right = 12.0;
  int? _selected;

  List<PortfolioPoint> get _points =>
      [...widget.points]..sort((a, b) => a.date.compareTo(b.date));

  @override
  void didUpdateWidget(covariant InteractiveReturnChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.points, oldWidget.points)) _selected = null;
  }

  void _selectAt(double x, double width, List<PortfolioPoint> points) {
    if (points.isEmpty) return;
    final available = math.max(1.0, width - _left - _right);
    final first = points.first.date.millisecondsSinceEpoch;
    final last = points.last.date.millisecondsSinceEpoch;
    final duration = last - first;
    final fraction = ((x - _left) / available).clamp(0.0, 1.0);
    var closest = 0;
    var distance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final position = duration == 0
          ? i / math.max(1, points.length - 1)
          : (points[i].date.millisecondsSinceEpoch - first) / duration;
      final candidate = (position - fraction).abs();
      if (candidate < distance) {
        distance = candidate;
        closest = i;
      }
    }
    if (_selected != closest) setState(() => _selected = closest);
  }

  @override
  Widget build(BuildContext context) {
    final points = _points
        .where((p) => p.returnWithCurrencyEffect != null)
        .toList();
    if (points.length < 2) return const Text('Not enough historical data');
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected == null || _selected! >= points.length
        ? null
        : points[_selected!];
    final sameDay =
        points.first.date.year == points.last.date.year &&
        points.first.date.month == points.last.date.month &&
        points.first.date.day == points.last.date.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: 214,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _selectAt(
                details.localPosition.dx,
                constraints.maxWidth,
                points,
              ),
              onHorizontalDragStart: (details) => _selectAt(
                details.localPosition.dx,
                constraints.maxWidth,
                points,
              ),
              onHorizontalDragUpdate: (details) => _selectAt(
                details.localPosition.dx,
                constraints.maxWidth,
                points,
              ),
              child: CustomPaint(
                painter: _ChartPainter(
                  points: points,
                  selectedIndex: _selected,
                  lineColor: scheme.primary,
                  labelColor: scheme.onSurfaceVariant,
                  gridColor: scheme.outlineVariant,
                  sameDay: sameDay,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (selected == null)
          Text(
            'Touch the chart to inspect a value',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          )
        else
          Text(
            '${_dateLabel(selected.date, includeTime: sameDay)}  ·  '
            '${(selected.returnWithCurrencyEffect! * 100).toStringAsFixed(2)}%',
            key: const ValueKey('chart-selected-value'),
            style: Theme.of(context).textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

String _dateLabel(DateTime date, {bool includeTime = false}) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  if (!includeTime) return '$day/$month/$year';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.points,
    required this.selectedIndex,
    required this.lineColor,
    required this.labelColor,
    required this.gridColor,
    required this.sameDay,
  });

  final List<PortfolioPoint> points;
  final int? selectedIndex;
  final Color lineColor;
  final Color labelColor;
  final Color gridColor;
  final bool sameDay;

  static const _left = 56.0;
  static const _right = 12.0;
  static const _top = 10.0;
  static const _bottom = 32.0;

  void _label(Canvas canvas, String text, Offset offset, {bool right = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(right ? offset.dx - painter.width : offset.dx, offset.dy),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= _left + _right) return;
    final values = points.map((p) => p.returnWithCurrencyEffect!).toList();
    final minimum = math.min(0.0, values.reduce(math.min));
    final maximum = math.max(0.0, values.reduce(math.max));
    final rawSpan = maximum - minimum;
    // Keep a meaningful vertical range even for a flat, all-zero history.
    final padding = rawSpan == 0 ? 0.01 : rawSpan * 0.08;
    final low = minimum - padding;
    final high = maximum + padding;
    final span = high - low;
    final plotW = size.width - _left - _right;
    final plotH = size.height - _top - _bottom;
    final first = points.first.date.millisecondsSinceEpoch;
    final last = points.last.date.millisecondsSinceEpoch;
    final duration = last - first;

    double x(int i) =>
        _left +
        plotW *
            (duration == 0
                ? i / (points.length - 1)
                : (points[i].date.millisecondsSinceEpoch - first) / duration);
    double y(double value) => _top + plotH * (high - value) / span;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 0.7;
    for (var tick = 0; tick <= 4; tick++) {
      final value = low + (high - low) * tick / 4;
      final yy = y(value);
      canvas.drawLine(
        Offset(_left, yy),
        Offset(size.width - _right, yy),
        gridPaint,
      );
      _label(canvas, '${(value * 100).toStringAsFixed(1)}%', Offset(0, yy - 6));
    }
    final zeroY = y(0);
    canvas.drawLine(
      Offset(_left, zeroY),
      Offset(size.width - _right, zeroY),
      Paint()
        ..color = labelColor.withValues(alpha: 0.65)
        ..strokeWidth = 1,
    );

    final line = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < points.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Three time labels preserve their chronological positions.
    final middleDate = DateTime.fromMillisecondsSinceEpoch(
      first + duration ~/ 2,
      isUtc: points.first.date.isUtc,
    );
    String axisLabel(DateTime date) {
      if (!sameDay) return _dateLabel(date);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    _label(
      canvas,
      axisLabel(points.first.date),
      Offset(_left, size.height - 15),
    );
    final middleLabel = axisLabel(middleDate);
    final middlePainter = TextPainter(
      text: TextSpan(
        text: middleLabel,
        style: TextStyle(fontSize: 10, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    middlePainter.paint(
      canvas,
      Offset((size.width - middlePainter.width) / 2, size.height - 15),
    );
    _label(
      canvas,
      axisLabel(points.last.date),
      Offset(size.width - _right, size.height - 15),
      right: true,
    );

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final index = selectedIndex!;
      final xx = x(index);
      final yy = y(values[index]);
      canvas.drawLine(
        Offset(xx, _top),
        Offset(xx, _top + plotH),
        Paint()
          ..color = labelColor.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(xx, yy), 5, Paint()..color = lineColor);
      canvas.drawCircle(Offset(xx, yy), 2, Paint()..color = gridColor);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points ||
      old.selectedIndex != selectedIndex ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor ||
      old.sameDay != sameDay;
}
