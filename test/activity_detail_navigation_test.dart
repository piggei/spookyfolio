import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_feed.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/holding_transactions.dart';
import 'package:spookyfolio/portfolio_client.dart';

const activityId = '11111111-2222-3333-4444-555555555555';

class NavigationClient extends PortfolioClient {
  int listCalls = 0;
  int detailCalls = 0;
  final offsets = <int>[];

  PortfolioActivity get item => PortfolioActivity(
    id: activityId,
    date: DateTime.utc(2026, 11, 20),
    type: 'BUY',
    name: 'Navigation ETF',
    symbol: 'VWCE.MI',
    currency: 'EUR',
    assetCurrency: 'EUR',
    dataSource: 'YAHOO',
    quantity: 2,
    unitPrice: 100,
    value: 200,
    valueInBaseCurrency: 220,
  );

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    listCalls++;
    offsets.add(skip);
    return ActivityBatch(activities: [item], count: 1);
  }

  @override
  Future<ActivityBatch> getHoldingActivities({
    required String serverUrl,
    required String jwt,
    required String dataSource,
    required String symbol,
    int skip = 0,
    int take = 20,
  }) async {
    listCalls++;
    offsets.add(skip);
    return ActivityBatch(activities: [item], count: 1);
  }

  @override
  Future<PortfolioActivity> getActivityById({
    required String serverUrl,
    required String jwt,
    required String activityId,
  }) async {
    detailCalls++;
    expect(activityId, NavigationClientActivity.id);
    return item;
  }
}

class NavigationClientActivity {
  static const id = activityId;
}

void main() {
  testWidgets('Activity detail Back preserves loaded feed', (tester) async {
    final api = NavigationClient();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityFeed(
            serverUrl: 'https://ghostfol.io',
            jwt: 'jwt-test',
            baseCurrency: 'USD',
            active: true,
            client: api,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(api.listCalls, 1);
    expect(find.text('Navigation ETF'), findsOneWidget);

    await tester.tap(find.text('Navigation ETF'));
    await tester.pumpAndSettle();

    expect(api.detailCalls, 1);
    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text('220.00 USD'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Navigation ETF'), findsOneWidget);
    expect(api.listCalls, 1);
    expect(api.offsets, [0]);
  });

  testWidgets('Holding detail Back preserves transactions', (tester) async {
    final api = NavigationClient();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HoldingTransactions(
              serverUrl: 'https://ghostfol.io',
              jwt: 'jwt-test',
              dataSource: 'YAHOO',
              symbol: 'VWCE.MI',
              baseCurrency: 'USD',
              client: api,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(api.listCalls, 1);

    await tester.tap(find.text('Navigation ETF'));
    await tester.pumpAndSettle();

    expect(api.detailCalls, 1);
    expect(find.text('Transaction details'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Navigation ETF'), findsOneWidget);
    expect(api.listCalls, 1);
    expect(api.offsets, [0]);
  });
}
