import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_feed.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/asset_lookup_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

const accountId = '11111111-2222-3333-4444-555555555555';

class FilterClient extends PortfolioClient {
  int allCalls = 0;
  int filteredCalls = 0;
  int lookupCalls = 0;

  final requestedAccounts = <String?>[];
  final requestedAssets = <String?>[];

  Completer<AssetLookupResults>? lookupCompleter;

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    allCalls++;
    requestedAccounts.add(null);
    requestedAssets.add(null);
    return ActivityBatch(activities: [], count: 0);
  }

  @override
  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    allCalls++;
    requestedAccounts.add(accountId);
    requestedAssets.add(null);
    return ActivityBatch(activities: [], count: 0);
  }

  @override
  Future<AssetLookupResults> lookupAssets({
    required String serverUrl,
    required String jwt,
    required String query,
  }) {
    lookupCalls++;
    if (lookupCompleter != null) {
      return lookupCompleter!.future;
    }
    return Future.value(
      AssetLookupResults([
        const AssetLookupItem(
          symbol: 'VWCE.MI',
          name: 'Vanguard ETF',
          currency: 'EUR',
          dataSource: 'YAHOO',
        ),
      ]),
    );
  }

  @override
  Future<ActivityBatch> getFilteredActivities({
    required String serverUrl,
    required String jwt,
    String? accountId,
    String? dataSource,
    String? symbol,
    int skip = 0,
    int take = 40,
  }) async {
    filteredCalls++;
    requestedAccounts.add(accountId);
    requestedAssets.add('$dataSource:$symbol');
    return ActivityBatch(activities: [], count: 0);
  }
}

Widget app(FilterClient api, {bool active = true, String? selectedAccount}) {
  return MaterialApp(
    home: Scaffold(
      body: ActivityFeed(
        key: const ValueKey('filter-feed'),
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt-test',
        active: active,
        enableAssetFilter: true,
        accountId: selectedAccount,
        client: api,
      ),
    ),
  );
}

void main() {
  testWidgets('selecting an asset applies server-side filter', (tester) async {
    final api = FilterClient();

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter by asset'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'VWCE');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(api.lookupCalls, 1);
    expect(find.text('Vanguard ETF'), findsOneWidget);

    await tester.tap(find.text('Vanguard ETF'));
    await tester.pumpAndSettle();

    expect(api.filteredCalls, 1);
    expect(api.requestedAssets.last, 'YAHOO:VWCE.MI');
    expect(find.text('VWCE.MI · YAHOO'), findsOneWidget);
  });

  testWidgets('asset filter is combined with selected account', (tester) async {
    final api = FilterClient();

    await tester.pumpWidget(app(api, selectedAccount: accountId));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter by asset'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'VWCE');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vanguard ETF'));
    await tester.pumpAndSettle();

    expect(api.filteredCalls, 1);
    expect(api.requestedAccounts.last, accountId);
    expect(api.requestedAssets.last, 'YAHOO:VWCE.MI');
  });

  testWidgets('leaving Activity clears the temporary asset filter', (
    tester,
  ) async {
    final api = FilterClient();

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter by asset'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'VWCE');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vanguard ETF'));
    await tester.pumpAndSettle();

    expect(api.filteredCalls, 1);

    await tester.pumpWidget(app(api, active: false));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(api.allCalls, 2);
    expect(api.filteredCalls, 1);
    expect(api.requestedAssets.last, isNull);
    expect(find.text('Filter by asset'), findsOneWidget);
    expect(find.text('VWCE.MI · YAHOO'), findsNothing);
  });

  testWidgets('changing account clears the selected asset filter', (
    tester,
  ) async {
    final api = FilterClient();

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter by asset'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'VWCE');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vanguard ETF'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(api, selectedAccount: accountId));
    await tester.pumpAndSettle();

    expect(api.filteredCalls, 1);
    expect(api.allCalls, 2);
    expect(api.requestedAccounts.last, accountId);
    expect(api.requestedAssets.last, isNull);
    expect(find.text('VWCE.MI · YAHOO'), findsNothing);
  });
}
