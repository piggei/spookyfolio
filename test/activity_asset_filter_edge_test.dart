import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_feed.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/asset_lookup_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

const staleId = '11111111-2222-3333-4444-555555555555';

AssetLookupItem vwce() => const AssetLookupItem(
  symbol: 'VWCE.MI',
  name: 'Vanguard ETF',
  currency: 'EUR',
  dataSource: 'YAHOO',
);

AssetLookupItem iwda() => const AssetLookupItem(
  symbol: 'IWDA.AS',
  name: 'iShares ETF',
  currency: 'EUR',
  dataSource: 'YAHOO',
);

PortfolioActivity staleActivity() => PortfolioActivity(
  id: staleId,
  date: DateTime.utc(2026, 11, 20),
  type: 'BUY',
  name: 'Stale transaction',
  symbol: 'VWCE.MI',
  currency: 'EUR',
  quantity: 1,
  unitPrice: 100,
  value: 100,
  fee: 0,
);

class EdgeClient extends PortfolioClient {
  Future<AssetLookupResults> Function(String query)? lookupHandler;
  Future<ActivityBatch> Function(String? source, String? symbol, int skip)?
  filteredHandler;

  final requestedAssets = <String?>[];
  final requestedOffsets = <int>[];

  int lookupCalls = 0;
  int allCalls = 0;
  int filteredCalls = 0;

  @override
  Future<AssetLookupResults> lookupAssets({
    required String serverUrl,
    required String jwt,
    required String query,
  }) {
    lookupCalls++;

    if (lookupHandler != null) {
      return lookupHandler!(query);
    }

    return Future.value(AssetLookupResults([vwce()]));
  }

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    allCalls++;
    return ActivityBatch(activities: [], count: 0);
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
  }) {
    filteredCalls++;
    requestedAssets.add('$dataSource:$symbol');
    requestedOffsets.add(skip);

    if (filteredHandler != null) {
      return filteredHandler!(dataSource, symbol, skip);
    }

    return Future.value(ActivityBatch(activities: [], count: 0));
  }
}

Widget edgeApp(EdgeClient api) => MaterialApp(
  home: Scaffold(
    body: ActivityFeed(
      key: const ValueKey('edge-filter-feed'),
      serverUrl: 'https://ghostfol.io',
      jwt: 'jwt-test',
      active: true,
      enableAssetFilter: true,
      client: api,
    ),
  ),
);

Future<void> selectAsset(
  WidgetTester tester, {
  required String query,
  required String result,
  bool alreadyFiltered = false,
  bool waitForLoad = true,
}) async {
  if (alreadyFiltered) {
    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
  } else {
    await tester.tap(find.text('Filter by asset'));
  }

  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();

  await tester.tap(find.text(result));

  if (waitForLoad) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('changing asset resets server pagination', (tester) async {
    final api = EdgeClient()
      ..lookupHandler = (query) async =>
          AssetLookupResults([query == 'VWCE' ? vwce() : iwda()]);

    await tester.pumpWidget(edgeApp(api));
    await tester.pumpAndSettle();

    await selectAsset(tester, query: 'VWCE', result: 'Vanguard ETF');

    await selectAsset(
      tester,
      query: 'IWDA',
      result: 'iShares ETF',
      alreadyFiltered: true,
    );

    expect(api.filteredCalls, 2);
    expect(api.requestedAssets, ['YAHOO:VWCE.MI', 'YAHOO:IWDA.AS']);
    expect(api.requestedOffsets, [0, 0]);
    expect(find.text('IWDA.AS · YAHOO'), findsOneWidget);
    expect(find.text('VWCE.MI · YAHOO'), findsNothing);
  });

  testWidgets('stale lookup response cannot replace newer results', (
    tester,
  ) async {
    final stale = Completer<AssetLookupResults>();

    final api = EdgeClient()
      ..lookupHandler = (query) {
        if (query == 'VWCE') return stale.future;
        return Future.value(AssetLookupResults([iwda()]));
      };

    await tester.pumpWidget(edgeApp(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter by asset'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField);

    await tester.enterText(field, 'VWCE');
    await tester.pump(const Duration(milliseconds: 350));

    expect(api.lookupCalls, 1);

    await tester.enterText(field, 'IWDA');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('iShares ETF'), findsOneWidget);

    stale.complete(AssetLookupResults([vwce()]));
    await tester.pumpAndSettle();

    expect(find.text('iShares ETF'), findsOneWidget);
    expect(find.text('Vanguard ETF'), findsNothing);
  });

  testWidgets('clearing filter invalidates pending activity response', (
    tester,
  ) async {
    final pending = Completer<ActivityBatch>();

    final api = EdgeClient()
      ..filteredHandler = (source, symbol, skip) => pending.future;

    await tester.pumpWidget(edgeApp(api));
    await tester.pumpAndSettle();

    await selectAsset(
      tester,
      query: 'VWCE',
      result: 'Vanguard ETF',
      waitForLoad: false,
    );

    expect(api.filteredCalls, 1);

    await tester.tap(find.byTooltip('Clear asset filter'));
    await tester.pumpAndSettle();

    expect(api.allCalls, 2);
    expect(find.text('VWCE.MI · YAHOO'), findsNothing);

    pending.complete(ActivityBatch(activities: [staleActivity()], count: 1));

    await tester.pumpAndSettle();

    expect(find.text('Stale transaction'), findsNothing);
    expect(find.text('Filter by asset'), findsOneWidget);
    expect(api.filteredCalls, 1);
    expect(api.allCalls, 2);
  });
}
