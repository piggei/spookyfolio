import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/holding_detail.dart';
import 'package:spookyfolio/holding_detail_data.dart';
import 'package:spookyfolio/holding_price_chart.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test('historical market prices and average costs retain API values', () {
    final detail = HoldingDetailData.fromJson({
      'assetProfile': {
        'symbol': 'VWCE.MI',
        'currency': 'EUR',
        'isin': 'IE00BK5BQT80',
        'assetClass': 'EQUITY',
        'dataSource': '4534c002',
      },
      'historicalData': [
        {'date': '2026-11-16', 'marketPrice': 169.1, 'averagePrice': 165.1},
        {'date': '2026-11-15', 'marketPrice': null, 'averagePrice': 164.9},
      ],
      'activitiesCount': 4,
      'dividendYieldPercentWithCurrencyEffect': 0.02,
      'dateOfFirstActivity': '2026-06-08T00:00:00.000Z',
    });
    expect(detail.history.length, 2);
    expect(detail.history.first.marketPrice, isNull);
    expect(detail.history.last.marketPrice, 169.1);
    expect(detail.history.last.averagePrice, 165.1);
    expect(detail.isin, 'IE00BK5BQT80');
    expect(detail.assetClass, 'EQUITY');
    expect(detail.dividendYieldPercentWithCurrencyEffect, 0.02);
    expect(detail.dateOfFirstActivity, isNotNull);
  });

  test('nullable history and redacted values remain absent', () {
    final detail = HoldingDetailData.fromJson({
      'historicalData': null,
      'averagePrice': null,
    });
    expect(detail.history, isEmpty);
    expect(detail.averagePrice, isNull);
    expect(
      () => HoldingDetailData.fromJson({
        'historicalData': [
          {'date': 'bad', 'marketPrice': 10},
        ],
      }),
      throwsFormatException,
    );
  });

  testWidgets('cash currency does not request market details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HoldingDetailPage(
          holding: const PortfolioHolding(
            symbol: 'EUR',
            name: 'EUR',
            value: 1000,
            allocation: 0.5,
            dataSource: 'MANUAL',
          ),
          baseCurrency: 'EUR',
          serverUrl: 'https://example.com',
          jwt: 'test',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cash balance'), findsOneWidget);
    expect(find.textContaining('do not have a market price'), findsOneWidget);
  });

  testWidgets('detail chart responds to touches', (tester) async {
    final points = [
      HoldingPricePoint(
        date: DateTime(2026, 1, 1),
        marketPrice: 100,
        averagePrice: 95,
      ),
      HoldingPricePoint(
        date: DateTime(2026, 2, 1),
        marketPrice: 110,
        averagePrice: 98,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 350,
            child: HoldingPriceChart(points: points, currency: 'EUR'),
          ),
        ),
      ),
    );
    expect(find.textContaining('Market price'), findsOneWidget);
    final chart = find.descendant(
      of: find.byType(HoldingPriceChart),
      matching: find.byType(CustomPaint),
    );
    expect(chart, findsOneWidget);

    await tester.tapAt(tester.getCenter(chart));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('holding-price-selected')),
      findsOneWidget,
    );
  });
}
