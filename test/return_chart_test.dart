import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/portfolio_client.dart';
import 'package:spookyfolio/return_chart.dart';

void main() {
  final points = [
    PortfolioPoint(date: DateTime.utc(2026, 6, 1), returnWithCurrencyEffect: 0),
    PortfolioPoint(
      date: DateTime.utc(2026, 8, 1),
      returnWithCurrencyEffect: 0.04,
    ),
    PortfolioPoint(
      date: DateTime.utc(2026, 11, 21),
      returnWithCurrencyEffect: -0.0713,
    ),
  ];

  testWidgets('shows historical values at touch without recomputing them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InteractiveReturnChart(points: points)),
      ),
    );
    expect(find.text('Touch the chart to inspect a value'), findsOneWidget);
    final rect = tester.getRect(find.byType(InteractiveReturnChart));
    await tester.tapAt(Offset(rect.right - 18, rect.top + 90));
    await tester.pump();
    expect(find.byKey(const ValueKey('chart-selected-value')), findsOneWidget);
    expect(find.textContaining('-7.13%'), findsOneWidget);
  });

  testWidgets('handles flat history and dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: InteractiveReturnChart(
            points: [
              PortfolioPoint(
                date: DateTime.utc(2026, 1, 1),
                returnWithCurrencyEffect: 0,
              ),
              PortfolioPoint(
                date: DateTime.utc(2026, 1, 2),
                returnWithCurrencyEffect: 0,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
