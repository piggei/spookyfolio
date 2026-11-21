import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/holdings_page.dart';
import 'package:spookyfolio/holding_detail.dart';
import 'package:spookyfolio/holding_detail_data.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test('return colors follow sign and theme', () {
    final light = ThemeData.light().colorScheme;
    final dark = ThemeData.dark().colorScheme;
    expect(holdingReturnColor(light, .01), isNot(light.onSurface));
    expect(holdingReturnColor(light, -.01), isNot(light.onSurface));
    expect(
      holdingReturnColor(light, .01),
      isNot(holdingReturnColor(light, -.01)),
    );
    expect(holdingReturnColor(light, 0), light.onSurface);
    expect(holdingReturnColor(light, null), light.onSurface);
    expect(holdingReturnColor(dark, 0), dark.onSurface);
    expect(holdingReturnColor(dark, null), dark.onSurface);
  });

  testWidgets('asset summary scrolls inside Analysis, not above tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HoldingDetailPage(
          holding: const PortfolioHolding(
            symbol: 'VWCE.MI',
            name: 'World ETF',
            dataSource: '4534c002',
            value: 1000,
            allocation: .25,
          ),
          baseCurrency: 'EUR',
          serverUrl: 'https://ghostfol.io',
          jwt: 'test',
          loadDetail: () async =>
              HoldingDetailData(marketPrice: 175, averagePrice: 165),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byKey(const ValueKey('holding-analysis-tab')), findsOneWidget);
    expect(find.text('Current value'), findsOneWidget);
    await tester.tap(find.text('Asset').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holding-asset-tab')), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });
}
