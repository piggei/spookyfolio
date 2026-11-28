import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_feed.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

class FakeActivitiesClient extends PortfolioClient {
  int requests = 0;
  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    requests++;
    final activity = PortfolioActivity.fromJson({
      'id': 'buy-1',
      'date': '2026-11-16',
      'type': 'BUY',
      'currency': 'EUR',
      'quantity': 1,
      'unitPrice': 169.10,
      'fee': 0,
      'value': 169.10,
      'assetProfile': {'name': 'Vanguard ETF', 'symbol': 'VWCE.MI'},
    });
    return ActivityBatch(activities: [activity], count: 1);
  }
}

void main() {
  testWidgets('hides technical UUID symbols but preserves asset symbols', (
    tester,
  ) async {
    const technicalId = '11111111-2222-3333-4444-555555555555';

    PortfolioActivity item(String type, String symbol, String name) =>
        PortfolioActivity.fromJson({
          'id': 'test-$type',
          'date': '2026-11-20',
          'type': type,
          'currency': 'EUR',
          'quantity': 1,
          'unitPrice': 10,
          'fee': 0,
          'value': 10,
          'assetProfile': {'name': name, 'symbol': symbol},
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ActivityCard(
                activity: item('FEE', technicalId, 'Bollo portafoglio titoli'),
              ),
              ActivityCard(activity: item('BUY', 'VWCE.MI', 'Vanguard ETF')),
            ],
          ),
        ),
      ),
    );

    expect(find.text(technicalId), findsNothing);
    expect(find.text('Bollo portafoglio titoli'), findsOneWidget);
    expect(find.text('VWCE.MI'), findsOneWidget);
    expect(find.text('Vanguard ETF'), findsOneWidget);
  });

  testWidgets('loads lazily when activity tab becomes active', (tester) async {
    final client = FakeActivitiesClient();
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityFeed(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt',
          client: client,
          active: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.requests, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityFeed(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt',
          client: client,
          active: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.requests, 1);
    expect(find.text('Vanguard ETF'), findsOneWidget);
    expect(find.text('169.10 EUR'), findsOneWidget);
    expect(find.text('Quantity: 1.0000'), findsOneWidget);
  });
}
