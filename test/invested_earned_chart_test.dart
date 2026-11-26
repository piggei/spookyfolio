import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/invested_earned_chart.dart';
import 'package:spookyfolio/portfolio_client.dart';

PortfolioHistory history(
  List<Map<String, Object?>> points, {
  bool errors = false,
}) => PortfolioHistory.fromJson({'chart': points, 'hasErrors': errors});

Map<String, Object?> point(int day, double? invested, double? value) => {
  'date': '2026-01-${day.toString().padLeft(2, '0')}',
  'totalInvestmentValueWithCurrencyEffect': invested,
  'valueWithCurrencyEffect': value,
  'value': 999999,
  'valueInPercentage': .99,
};

Widget app(
  PortfolioHistory data, {
  String? currency = 'EUR',
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Object? revision,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: ListView(
        children: [
          InteractiveInvestedEarnedChart(
            history: data,
            baseCurrency: currency,
            contextRevision: revision,
          ),
        ],
      ),
    ),
  ),
);

Future<void> select(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(
    find.byKey(const ValueKey('invested-earned-plot')),
  );
  await tester.tapAt(
    Offset(rect.left + 12 + (rect.width - 24) * fraction, rect.center.dy),
  );
  await tester.pump();
}

// Capture actual canvas operations to verify gaps independently for each line.
class RecordingCanvas implements Canvas {
  final lines = <(Offset, Offset, Color)>[];
  final circles = <(Offset, Color)>[];
  final squares = <(Rect, Color)>[];
  @override
  void drawLine(Offset a, Offset b, Paint paint) =>
      lines.add((a, b, paint.color));
  @override
  void drawCircle(Offset center, double radius, Paint paint) =>
      circles.add((center, paint.color));
  @override
  void drawRect(Rect rect, Paint paint) => squares.add((rect, paint.color));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecordingCanvas record(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(InteractiveInvestedEarnedChart),
      matching: find.byType(CustomPaint),
    ),
  );
  final canvas = RecordingCanvas();
  paint.painter!.paint(canvas, const Size(300, 220));
  return canvas;
}

void main() {
  testWidgets(
    'plots both monetary lines and selects exact server amounts by date',
    (tester) async {
      final data = history([
        point(3, 100.123456789, 130.987654321),
        point(1, -20, 0),
        point(2, 80, 90),
      ]);
      await tester.pumpWidget(app(data));
      final canvas = record(tester);
      expect(canvas.circles, hasLength(1));
      expect(canvas.squares, hasLength(1));
      expect(canvas.circles.first.$2, isNot(canvas.squares.first.$2));
      expect(
        canvas.lines.where((l) => l.$3 == canvas.circles.first.$2),
        hasLength(2),
      );
      expect(
        canvas.lines.where((l) => l.$3 == canvas.squares.first.$2),
        hasLength(2),
      );
      expect(find.text('Invested Capital: 100.12 EUR'), findsOneWidget);
      expect(find.text('Portfolio Value: 130.99 EUR'), findsOneWidget);
      expect(
        data.points.first.totalInvestmentValueWithCurrencyEffect,
        100.123456789,
      );
      await select(tester, 0);
      expect(find.text('Invested Capital: -20.00 EUR'), findsOneWidget);
      expect(find.text('Portfolio Value: 0.00 EUR'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('evolution-selected-date')))
            .data,
        '2026-01-01 00:00',
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey('invested-earned-plot')),
      );
      await tester.dragFrom(
        Offset(rect.left + 12, rect.center.dy),
        Offset((rect.width - 24) / 2, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invested Capital: 80.00 EUR'), findsOneWidget);
      expect(find.text('Portfolio Value: 90.00 EUR'), findsOneWidget);
    },
  );

  testWidgets(
    'missing observations break each line without losing other values',
    (tester) async {
      await tester.pumpWidget(
        app(
          history([
            point(1, 1, 10),
            point(2, null, 20),
            point(3, 3, null),
            point(4, 4, 40),
            point(5, null, null),
            point(6, 6, 60),
          ], errors: true),
        ),
      );
      final canvas = record(tester);
      expect(canvas.circles, hasLength(1));
      expect(canvas.squares, hasLength(1));
      expect(
        canvas.lines.where((l) => l.$3 == canvas.circles.first.$2),
        hasLength(1),
      );
      expect(
        canvas.lines.where((l) => l.$3 == canvas.squares.first.$2),
        hasLength(1),
      );
      expect(
        find.text('The server reports incomplete historical data.'),
        findsOneWidget,
      );
      await select(tester, .2);
      expect(find.text('Invested Capital: Not available'), findsOneWidget);
      expect(find.text('Portfolio Value: 20.00 EUR'), findsOneWidget);
      await select(tester, .8);
      expect(find.text('Portfolio Value: Not available'), findsOneWidget);
    },
  );

  testWidgets('percentage-only restricted data never becomes money', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(history([point(1, null, null), point(2, null, null)])),
    );
    expect(find.textContaining('Access or subscription'), findsOneWidget);
    expect(record(tester).lines, isEmpty);
    expect(find.text('Invested Capital: Not available'), findsOneWidget);
    expect(find.text('Portfolio Value: Not available'), findsOneWidget);
    expect(find.textContaining('999999'), findsNothing);
    expect(find.textContaining('0.99'), findsNothing);
    await select(tester, 0);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('evolution-selected-date')))
          .data,
      '2026-01-01 00:00',
    );
  });

  testWidgets('empty history has an explicit empty state', (tester) async {
    await tester.pumpWidget(app(const PortfolioHistory([])));
    expect(
      find.text('No historical monetary data for this period'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invested-earned-plot')), findsNothing);
  });

  for (final amounts in [(0.0, 0.0), (-25.0, -12.5), (10.0, 20.0)]) {
    testWidgets('single point and flat history $amounts', (tester) async {
      await tester.pumpWidget(app(history([point(1, amounts.$1, amounts.$2)])));
      final canvas = record(tester);
      expect(canvas.circles, hasLength(1));
      expect(canvas.squares, hasLength(1));
      expect(canvas.circles.single.$1.dx, 150);
      await select(tester, 1);
      expect(
        find.text('Invested Capital: ${amounts.$1.toStringAsFixed(2)} EUR'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        app(
          history([
            point(1, amounts.$1, amounts.$2),
            point(2, amounts.$1, amounts.$2),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final currency in <String?>[null, '', 'EU', 'eur', ' EUR ', '€']) {
    testWidgets('missing or malformed currency $currency is never guessed', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(history([point(1, 10, 20)]), currency: currency),
      );
      expect(find.text('Base currency unavailable'), findsOneWidget);
      expect(
        find.text('Portfolio Value: 20.00 (currency unavailable)'),
        findsOneWidget,
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('small screen and enlarged text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          history([point(1, -10, 0), point(2, 100, 130)]),
          brightness: brightness,
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('evolution-selected-value')),
      );
      expect(tester.takeException(), isNull);
      final canvas = record(tester);
      expect(canvas.circles.first.$2, isNot(canvas.squares.first.$2));
    });
  }

  testWidgets(
    'new history and context reset selection; unchanged rebuild retains it',
    (tester) async {
      final data = history([point(1, 1, 2), point(2, 3, 4)]);
      await tester.pumpWidget(app(data, revision: 'account-a'));
      await select(tester, 0);
      await tester.pumpWidget(
        app(data, revision: 'account-a', brightness: Brightness.dark),
      );
      expect(find.text('Portfolio Value: 2.00 EUR'), findsOneWidget);
      await tester.pumpWidget(app(data, revision: 'account-b'));
      expect(find.text('Portfolio Value: 4.00 EUR'), findsOneWidget);
      await select(tester, 0);
      await tester.pumpWidget(
        app(history([point(3, 5, 6)]), revision: 'account-b'),
      );
      expect(find.text('Portfolio Value: 6.00 EUR'), findsOneWidget);
    },
  );

  testWidgets('long histories render only selected markers', (tester) async {
    final start = DateTime.utc(2020, 1, 1);
    final points = [
      for (var i = 0; i < 1000; i++)
        {
          'date': start.add(Duration(days: i)).toIso8601String(),
          'totalInvestmentValueWithCurrencyEffect': 1000.0 + i,
          'valueWithCurrencyEffect': 1200.0 + i * 1.1,
        },
    ];

    await tester.pumpWidget(app(history(points)));

    final canvas = record(tester);

    expect(canvas.circles, hasLength(1));
    expect(canvas.squares, hasLength(1));

    final investedColor = canvas.circles.single.$2;
    final portfolioColor = canvas.squares.single.$2;

    expect(
      canvas.lines.where((line) => line.$3 == investedColor),
      hasLength(999),
    );
    expect(
      canvas.lines.where((line) => line.$3 == portfolioColor),
      hasLength(999),
    );

    expect(find.text('Invested Capital: 1999.00 EUR'), findsOneWidget);
    expect(find.text('Portfolio Value: 2298.90 EUR'), findsOneWidget);

    await select(tester, 0);

    expect(find.text('Invested Capital: 1000.00 EUR'), findsOneWidget);
    expect(find.text('Portfolio Value: 1200.00 EUR'), findsOneWidget);
  });

  testWidgets('extreme finite values have finite geometry', (tester) async {
    await tester.pumpWidget(
      app(history([point(1, -1e308, 1e308), point(2, 1e308, -1e308)])),
    );
    for (final marker in record(tester).circles) {
      expect(marker.$1.dx.isFinite && marker.$1.dy.isFinite, isTrue);
    }
    expect(tester.takeException(), isNull);
  });
}
