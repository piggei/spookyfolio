import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/holding_detail_data.dart';
import 'package:spookyfolio/holdings_page.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test(
    'holding details preserve API financial figures without recalculation',
    () {
      final detail = HoldingDetailData.fromJson({
        'quantity': 6,
        'averagePrice': 165.055,
        'netPerformanceWithCurrencyEffect': -34.23,
        'netPerformancePercentWithCurrencyEffect': -0.0713,
        'assetProfile': {'currency': 'EUR'},
        'activitiesCount': 4,
      });
      expect(detail.quantity, 6);
      expect(detail.averagePrice, 165.055);
      expect(detail.netPerformanceWithCurrencyEffect, -34.23);
      expect(detail.netPerformancePercentWithCurrencyEffect, -0.0713);
      expect(detail.activitiesCount, 4);
    },
  );

  test('redacted values stay null; malformed values fail explicitly', () {
    final detail = HoldingDetailData.fromJson({
      'quantity': 1,
      'netPerformance': null,
    });
    expect(detail.netPerformance, isNull);
    expect(
      () => HoldingDetailData.fromJson({'quantity': 'unknown'}),
      throwsFormatException,
    );
  });

  testWidgets('allocation donut shows holdings and actual supplied shares', (
    tester,
  ) async {
    final holdings = [
      const PortfolioHolding(symbol: 'EUR', name: 'Cash', allocation: 0.75),
      const PortfolioHolding(symbol: 'VWCE.MI', name: 'ETF', allocation: 0.25),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AllocationDonut(holdings: holdings),
          ),
        ),
      ),
    );
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('ETF'), findsOneWidget);
    expect(find.text('75.00%'), findsOneWidget);
    expect(find.text('25.00%'), findsOneWidget);
    expect(find.textContaining('incomplete'), findsNothing);
  });

  testWidgets('missing allocation is not silently normalized', (tester) async {
    final holdings = [
      const PortfolioHolding(symbol: 'AAA', name: 'Available', allocation: 0.3),
      const PortfolioHolding(symbol: 'BBB', name: 'Unknown'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AllocationDonut(holdings: holdings),
          ),
        ),
      ),
    );
    expect(find.text('30.00%'), findsOneWidget);
    expect(find.textContaining('incomplete'), findsOneWidget);
  });
}
