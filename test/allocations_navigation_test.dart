import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/mobile_shell.dart';
import 'package:spookyfolio/allocations_page.dart';
import 'package:spookyfolio/portfolio_client.dart';

import 'support/local_map_bundle.dart';

const account = '11111111-2222-3333-4444-555555555555';
Map<String, dynamic> body([String marker = 'Current allocation']) {
  final json = jsonDecode(
    File('test/fixtures/dashboard_portfolio.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  json['accounts'] = {
    account: {'name': marker, 'currency': 'EUR', 'valueInBaseCurrency': 1000},
  };
  return json;
}

http.Response response(Object json) => http.Response(
  jsonEncode(json),
  200,
  headers: {'content-type': 'application/json'},
);

class Api {
  final requests = <http.Request>[];
  bool failProfile = false;
  Future<http.Response> Function(http.Request)? allocations;
  late final client = PortfolioClient(
    clientFactory: () => MockClient((request) async {
      requests.add(request);
      switch (request.url.path) {
        case '/api/v1/user':
          if (failProfile) return http.Response('', 500);
          return response({
            'id': 'user',
            'settings': {
              'baseCurrency': 'EUR',
              'performanceCalculationType': 'ROAI',
            },
          });
        case '/api/v1/portfolio/details':
          if (request.url.queryParameters['withMarkets'] == 'true') {
            return allocations?.call(request) ?? response(body());
          }
          return response(body('Ordinary snapshot'));
        case '/api/v2/portfolio/performance':
          return response({
            'performance': {'currentValueInBaseCurrency': 1000},
            'chart': [
              {
                'date': '2026-01-01',
                'netPerformanceInPercentageWithCurrencyEffect': 0,
              },
              {
                'date': '2026-02-01',
                'netPerformanceInPercentageWithCurrencyEffect': .1,
              },
            ],
          });
        case '/api/v1/accounts':
          return response({
            'accounts': [
              {
                'id': account,
                'name': 'Brokerage filter',
                'currency': 'EUR',
                'valueInBaseCurrency': 1000,
              },
            ],
          });
        case '/api/v1/activities':
          return response({'activities': [], 'count': 0});
        default:
          throw StateError('Unexpected request ${request.url}');
      }
    }),
  );
  int count(String path) => requests.where((r) => r.url.path == path).length;
  List<http.Request> get allocationRequests => requests
      .where((r) => r.url.queryParameters['withMarkets'] == 'true')
      .toList();
  int get ordinaryDetails => requests
      .where(
        (r) =>
            r.url.path == '/api/v1/portfolio/details' &&
            !r.url.queryParameters.containsKey('withMarkets'),
      )
      .length;
}

Widget app(
  Api api, {
  String jwt = 'jwt',
  String server = 'https://ghostfol.io',
}) => MaterialApp(
  home: DefaultAssetBundle(
    bundle: LocalMapBundle(),
    child: MobileShell(
      serverUrl: server,
      jwt: jwt,
      client: api.client,
      onSignOut: () async {},
    ),
  ),
);
Future<void> allocations(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byKey(const ValueKey('destination-allocations')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> section(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('main-navigation')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('section-$name')));
  await tester.pumpAndSettle();
}

Future<void> refresh(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byKey(const ValueKey('main-navigation')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const ValueKey('refresh-navigation')));
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> chooseAccount(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byTooltip('Select account'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Brokerage filter').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (settle) await tester.pumpAndSettle();
}

String currentMarker(WidgetTester tester) => tester
    .widget<AllocationsContent>(find.byType(AllocationsContent))
    .snapshot
    .accounts!
    .values
    .single
    .name!;

void main() {
  testWidgets(
    'Dashboard navigation loads lazily and retains Allocations without duplicate requests',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      expect(api.allocationRequests, isEmpty);
      expect(api.ordinaryDetails, 1);
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .cast<NavigationDestination>()
            .map((d) => d.label),
        ['Overview', 'Allocations', 'Invested vs Earned'],
      );
      await allocations(tester);
      expect(api.allocationRequests, hasLength(1));
      expect(find.byType(AllocationsContent), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await tester.tap(find.byKey(const ValueKey('destination-overview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      await allocations(tester);
      await section(tester, 'portfolio');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AllocationsContent), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(api.allocationRequests, hasLength(1));
      expect(api.count('/api/v1/user'), 1);
    },
  );

  testWidgets('Dashboard horizontal swipes synchronize the bottom selection', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    final pages = find.byKey(const ValueKey('dashboard-swipe-pages'));
    await tester.dragFrom(const Offset(400, 140), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.byType(AllocationsContent), findsOneWidget);
    await tester.drag(pages, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(api.allocationRequests, hasLength(1));
  });

  testWidgets(
    'global filter is sent to the allocation REST request and retains the active subsection',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await chooseAccount(tester);
      await allocations(tester);
      expect(api.allocationRequests.single.url.queryParameters, {
        'withMarkets': 'true',
        'accounts': account,
      });
      expect(
        api.allocationRequests.single.headers['authorization'],
        'Bearer jwt',
      );
      expect(find.text('Account: Brokerage filter'), findsOneWidget);
      expect(currentMarker(tester), 'Current allocation');
      await refresh(tester);
      expect(api.allocationRequests, hasLength(2));
      expect(
        api.allocationRequests.every(
          (r) => r.url.queryParameters['accounts'] == account,
        ),
        isTrue,
      );
      expect(
        api.count('/api/v1/user'),
        2,
      ); // Initial load and account change only.
      expect(api.ordinaryDetails, 2);
    },
  );

  testWidgets(
    'account changes during loading discard old responses and share one enriched request',
    (tester) async {
      final old = Completer<http.Response>();
      final filtered = Completer<http.Response>();
      final api = Api();
      api.allocations = (request) =>
          request.url.queryParameters['accounts'] == account
          ? filtered.future
          : old.future;
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await allocations(tester, settle: false);
      expect(find.byKey(const ValueKey('allocations-loading')), findsOneWidget);
      await chooseAccount(tester, settle: false);
      expect(api.allocationRequests, hasLength(2));
      expect(api.ordinaryDetails, 1);
      filtered.complete(response(body('Filtered allocation')));
      await tester.pumpAndSettle();
      expect(currentMarker(tester), 'Filtered allocation');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      old.complete(response(body('Stale allocation')));
      await tester.pumpAndSettle();
      expect(currentMarker(tester), 'Filtered allocation');
      expect(api.ordinaryDetails, 1);
      expect(api.count('/api/v1/user'), 2);
    },
  );

  testWidgets(
    'menu Refresh updates allocations only; overlapping requests use the latest result',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await allocations(tester);
      final old = Completer<http.Response>();
      final newest = Completer<http.Response>();
      var index = 0;
      api.allocations = (_) => index++ == 0 ? old.future : newest.future;
      await refresh(tester, settle: false);
      await refresh(tester, settle: false);
      newest.complete(response(body('Latest refresh')));
      await tester.pumpAndSettle();
      expect(currentMarker(tester), 'Latest refresh');
      old.complete(response(body('Old refresh')));
      await tester.pumpAndSettle();
      expect(currentMarker(tester), 'Latest refresh');
      expect(api.count('/api/v1/user'), 1);
      expect(api.count('/api/v2/portfolio/performance'), 1);
      expect(api.ordinaryDetails, 1);
      expect(api.allocationRequests, hasLength(3));
    },
  );

  testWidgets(
    'allocation errors have local retry and do not reload unrelated data',
    (tester) async {
      final api = Api();
      api.allocations = (_) async => http.Response('', 500);
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await allocations(tester);
      expect(find.text('Could not load allocations.'), findsOneWidget);
      api.allocations = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(AllocationsContent), findsOneWidget);
      expect(api.allocationRequests, hasLength(2));
      expect(api.count('/api/v1/user'), 1);
      expect(api.count('/api/v2/portfolio/performance'), 1);
    },
  );

  for (final changeServer in [false, true]) {
    testWidgets(
      'session ${changeServer ? 'server' : 'JWT'} change isolates pending allocation data',
      (tester) async {
        final old = Completer<http.Response>();
        final api = Api();
        api.allocations = (_) => old.future;
        await tester.pumpWidget(app(api));
        await tester.pumpAndSettle();
        await allocations(tester, settle: false);
        api.allocations = null;
        await tester.pumpWidget(
          app(
            api,
            jwt: changeServer ? 'jwt' : 'new-jwt',
            server: changeServer
                ? 'https://new.example'
                : 'https://ghostfol.io',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
        expect(find.byType(AllocationsContent), findsNothing);
        old.complete(response(body('Old session')));
        await tester.pumpAndSettle();
        await allocations(tester);
        expect(currentMarker(tester), 'Current allocation');
        final latest = api.allocationRequests.last;
        expect(latest.url.host, changeServer ? 'new.example' : 'ghostfol.io');
        expect(
          latest.headers['authorization'],
          changeServer ? 'Bearer jwt' : 'Bearer new-jwt',
        );
        expect(api.allocationRequests, hasLength(2));
      },
    );
  }

  testWidgets(
    'Overview range and filtered account state survive visits to Allocations',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'YTD'));
      await tester.pumpAndSettle();
      await allocations(tester);
      await chooseAccount(tester);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(
        api.ordinaryDetails,
        2,
      ); // Initial + range, not a duplicate on account change.
      await tester.tap(find.byKey(const ValueKey('destination-overview')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'YTD'))
            .selected,
        isTrue,
      );
      expect(
        api.requests
            .where((r) => r.url.path == '/api/v2/portfolio/performance')
            .last
            .url
            .queryParameters,
        {'range': 'ytd', 'accounts': account},
      );
      expect(find.text('Account: Brokerage filter'), findsOneWidget);
    },
  );
  testWidgets(
    'map selection and scroll position survive navigation and the map permits subsection swipes',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await allocations(tester);
      final vertical = find
          .descendant(
            of: find.byKey(const PageStorageKey('allocations-page')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('allocation-country-selector')),
        400,
        scrollable: vertical,
        maxScrolls: 80,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('allocation-country-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DE · Germany').last);
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(vertical).position.pixels;
      await section(tester, 'portfolio');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('allocation-map-selection')),
        findsOneWidget,
      );
      expect(
        tester.state<ScrollableState>(vertical).position.pixels,
        closeTo(offset, .1),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('allocation-world-map')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('allocation-world-map')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await allocations(tester);
      expect(
        find.byKey(const ValueKey('allocation-map-selection')),
        findsOneWidget,
      );
      expect(api.allocationRequests, hasLength(1));
    },
  );

  testWidgets(
    'allocation refresh never publishes previous-account history after a shared snapshot error',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await allocations(tester);
      api.failProfile = true;
      await chooseAccount(tester);
      expect(find.text('Could not update portfolio data.'), findsOneWidget);
      await refresh(tester);
      expect(find.text('Could not update portfolio data.'), findsOneWidget);
      api.failProfile = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Could not update portfolio data.'), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(currentMarker(tester), 'Current allocation');
      expect(
        api.requests
            .where((r) => r.url.path == '/api/v2/portfolio/performance')
            .last
            .url
            .queryParameters['accounts'],
        account,
      );
    },
  );
}
