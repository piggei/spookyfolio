import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/holding_detail.dart';
import 'package:spookyfolio/holding_detail_data.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  testWidgets('holding details switch between analysis and asset tabs', (
    tester,
  ) async {
    var requests = 0;
    final detail = HoldingDetailData(
      marketPrice: 175,
      averagePrice: 165,
      quantity: 6,
      isin: 'IE00BK5BQT80',
      assetCurrency: 'EUR',
      activitiesCount: 4,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HoldingDetailPage(
          holding: const PortfolioHolding(
            symbol: 'VWCE.MI',
            name: 'World ETF',
            dataSource: '4534c002',
            value: 1000,
            allocation: 0.25,
          ),
          baseCurrency: 'EUR',
          serverUrl: 'https://ghostfol.io',
          jwt: 'test',
          loadDetail: () async {
            requests++;
            return detail;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holding-analysis-tab')), findsOneWidget);
    expect(find.text('Market price'), findsOneWidget);
    expect(find.text('IE00BK5BQT80'), findsNothing);
    await tester.tap(find.text('Asset').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holding-asset-tab')), findsOneWidget);
    expect(find.text('IE00BK5BQT80'), findsOneWidget);
    expect(find.text('Current value'), findsNothing);
    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holding-analysis-tab')), findsOneWidget);
    expect(find.text('Current value'), findsOneWidget);
    expect(requests, 1);
  });

  testWidgets('cash stays in simplified view without asset tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HoldingDetailPage(
          holding: PortfolioHolding(
            symbol: 'EUR',
            name: 'EUR',
            dataSource: 'MANUAL',
            value: 1000,
            allocation: 0.6,
          ),
          baseCurrency: 'EUR',
          serverUrl: 'https://ghostfol.io',
          jwt: 'test',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cash balance'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Current value'), findsOneWidget);
  });
}
