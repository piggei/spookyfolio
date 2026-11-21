import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/holding_detail.dart';
import 'package:spookyfolio/holding_detail_data.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  Future<void> showDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HoldingDetailPage(
          holding: const PortfolioHolding(
            symbol: 'TEST',
            name: 'Test asset',
            dataSource: 'TEST',
            value: 640.16,
            allocation: 0.0371,
            netPerformancePercent: 0.125,
          ),
          baseCurrency: 'EUR',
          serverUrl: 'https://ghostfol.io',
          jwt: 'test',
          loadDetail: () async => const HoldingDetailData(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('summary shows three supplied metrics in one card', (
    tester,
  ) async {
    await showDetail(tester);

    expect(find.byKey(const ValueKey('holding-summary-strip')), findsOneWidget);
    expect(find.text('640.16 EUR'), findsOneWidget);
    expect(find.text('3.71%'), findsOneWidget);
    expect(find.text('12.50%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary adapts to narrow display', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await showDetail(tester);

    expect(find.byKey(const ValueKey('holding-summary-strip')), findsOneWidget);
    expect(find.text('640.16 EUR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
