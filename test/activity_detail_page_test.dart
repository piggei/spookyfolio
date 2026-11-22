import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_detail_page.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

const activityId = '11111111-2222-3333-4444-555555555555';
const secondId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

class FakeActivityDetailClient extends PortfolioClient {
  int calls = 0;
  final requestedIds = <String>[];
  Future<PortfolioActivity> Function(String id)? response;

  @override
  Future<PortfolioActivity> getActivityById({
    required String serverUrl,
    required String jwt,
    required String activityId,
  }) {
    calls++;
    requestedIds.add(activityId);

    if (response != null) return response!(activityId);

    return Future.value(activity(activityId));
  }
}

PortfolioActivity activity(String id, {bool extended = true}) =>
    PortfolioActivity(
      id: id,
      date: DateTime.utc(2026, 11, 20),
      type: 'BUY',
      name: 'Example ETF',
      symbol: 'EXAMPLE',
      currency: 'EUR',
      quantity: 2,
      unitPrice: 100.25,
      fee: 1.5,
      value: 200.5,
      accountName: 'Brokerage',
      dataSource: extended ? 'YAHOO' : null,
      assetCurrency: extended ? 'USD' : null,
      isin: extended ? 'IE0000000001' : null,
      comment: extended ? 'Long-term investment' : null,
      valueInBaseCurrency: extended ? 210.75 : null,
      feeInBaseCurrency: extended ? 1.65 : null,
      unitPriceInAssetProfileCurrency: extended ? 98.5 : null,
      feeInAssetProfileCurrency: extended ? 1.4 : null,
    );

Widget detailApp(
  FakeActivityDetailClient api, {
  String id = activityId,
  String jwt = 'jwt-test',
}) => MaterialApp(
  home: ActivityDetailPage(
    activityId: id,
    serverUrl: 'https://ghostfol.io',
    jwt: jwt,
    baseCurrency: 'USD',
    client: api,
  ),
);

void main() {
  testWidgets('loads and displays transaction details', (tester) async {
    final api = FakeActivityDetailClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(
      find.byKey(const ValueKey('activity-detail-content')),
      findsOneWidget,
    );
    expect(find.text('Example ETF'), findsOneWidget);
    expect(find.text('200.50 EUR'), findsWidgets);
    expect(find.text('100.25 EUR'), findsOneWidget);
    expect(find.text('1.50 EUR'), findsOneWidget);
    expect(find.text('Brokerage'), findsOneWidget);

    final list = find.byKey(const ValueKey('activity-detail-content'));

    await tester.scrollUntilVisible(
      find.text('Long-term investment'),
      150,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.text('Long-term investment'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('210.75 USD'),
      150,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.text('210.75 USD'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('98.50 USD'),
      150,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.text('98.50 USD'), findsOneWidget);
  });

  testWidgets('handles absent optional fields', (tester) async {
    final api = FakeActivityDetailClient()
      ..response = (id) async => activity(id, extended: false);

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-detail-content')),
      findsOneWidget,
    );
    expect(find.text('Portfolio base currency'), findsNothing);
    expect(find.text('Asset currency'), findsNothing);
    expect(find.text('Comment'), findsNothing);
  });

  testWidgets('shows not found and retries successfully', (tester) async {
    final api = FakeActivityDetailClient()
      ..response = (id) async {
        throw const PortfolioApiException('Not Found', statusCode: 404);
      };

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(find.text('Transaction not found.'), findsOneWidget);

    api.response = (id) async => activity(id);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(
      find.byKey(const ValueKey('activity-detail-content')),
      findsOneWidget,
    );
  });

  testWidgets('refresh reloads the selected transaction', (tester) async {
    final api = FakeActivityDetailClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh transaction'));
    await tester.pumpAndSettle();

    expect(api.calls, 2);
    expect(api.requestedIds, [activityId, activityId]);
  });

  testWidgets('switching transaction loads the new ID', (tester) async {
    final api = FakeActivityDetailClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    await tester.pumpWidget(detailApp(api, id: secondId));
    await tester.pumpAndSettle();

    expect(api.requestedIds, [activityId, secondId]);
  });

  testWidgets('stale response cannot replace the selected transaction', (
    tester,
  ) async {
    final pending = Completer<PortfolioActivity>();
    final api = FakeActivityDetailClient()
      ..response = (id) =>
          id == activityId ? pending.future : Future.value(activity(id));

    await tester.pumpWidget(detailApp(api));
    await tester.pump();

    await tester.pumpWidget(detailApp(api, id: secondId));
    await tester.pumpAndSettle();

    expect(api.requestedIds, [activityId, secondId]);

    pending.complete(activity(activityId));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-detail-content')),
      findsOneWidget,
    );
    expect(find.text('Example ETF'), findsOneWidget);
  });
}
