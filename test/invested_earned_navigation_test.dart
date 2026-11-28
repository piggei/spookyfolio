import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/invested_earned_chart.dart';
import 'package:spookyfolio/mobile_shell.dart';
import 'package:spookyfolio/portfolio_client.dart';

class Request {
  Request(this.server, this.jwt, this.account, this.range);
  final String server;
  final String jwt;
  final String? account;
  final String? range;
  final result = Completer<PortfolioHistory>();
}

PortfolioHistory money(double marker) => PortfolioHistory.fromJson({
  'chart': [
    {
      'date': '2026-01-01',
      'totalInvestmentValueWithCurrencyEffect': marker,
      'valueWithCurrencyEffect': marker + 1,
      'netPerformanceInPercentageWithCurrencyEffect': .1,
    },
    {
      'date': '2026-01-02',
      'totalInvestmentValueWithCurrencyEffect': marker + 2,
      'valueWithCurrencyEffect': marker + 3,
      'netPerformanceInPercentageWithCurrencyEffect': .2,
    },
  ],
});

class Api extends PortfolioClient {
  bool delay = false;
  bool historyFailure = false;
  int details = 0;
  final requests = <Request>[];

  @override
  Future<GhostfolioProfile> getProfile({
    required String serverUrl,
    required String jwt,
  }) async =>
      GhostfolioProfile(id: jwt, baseCurrency: jwt == 'new' ? 'USD' : 'EUR');

  @override
  Future<PortfolioSnapshot> getDetails({
    required String serverUrl,
    required String jwt,
  }) async {
    details++;
    return const PortfolioSnapshot(holdings: []);
  }

  @override
  Future<PortfolioSnapshot> getDetailsForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) => getDetails(serverUrl: serverUrl, jwt: jwt);

  @override
  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async => const PortfolioAccountsCatalog([
    PortfolioAccount(id: 'account-a', name: 'Account A', currency: 'GBP'),
    PortfolioAccount(id: 'account-b', name: 'Account B', currency: 'CHF'),
  ]);

  Future<PortfolioHistory> request(
    String server,
    String jwt,
    String? account,
    String? range,
  ) {
    final r = Request(server, jwt, account, range);
    requests.add(r);
    if (historyFailure) {
      return Future.error(
        const PortfolioApiException('Historical access restricted'),
      );
    }
    if (!delay) r.result.complete(money(account == null ? 10 : 100));
    return r.result.future;
  }

  @override
  Future<PortfolioHistory> getHistory({
    required String serverUrl,
    required String jwt,
    String? range,
  }) => request(serverUrl, jwt, null, range);

  @override
  Future<PortfolioHistory> getHistoryForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    String? range,
  }) => request(serverUrl, jwt, accountId, range);
}

Widget app(
  Api api, {
  String jwt = 'old',
  String server = 'https://example.test',
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: MobileShell(
    serverUrl: server,
    jwt: jwt,
    client: api,
    onSignOut: () async {},
  ),
);

Future<void> destination(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('destination-$name')));
  await tester.pumpAndSettle();
}

Future<void> section(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('main-navigation')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('section-$name')));
  await tester.pumpAndSettle();
}

Future<void> refresh(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('main-navigation')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const ValueKey('refresh-navigation')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> account(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Select account'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> range(WidgetTester tester, String value) async {
  final chip = find.widgetWithText(ChoiceChip, value);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'lazy third destination shares one snapshot and both range selectors',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      expect(
        find.byType(InteractiveInvestedEarnedChart, skipOffstage: false),
        findsNothing,
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        bar.destinations.cast<NavigationDestination>().map((d) => d.label),
        ['Overview', 'Invested vs Earned', 'Allocations'],
      );
      await range(tester, 'YTD');
      expect(api.requests.map((r) => r.range), ['max', 'ytd']);
      await destination(tester, 'investedEarned');
      expect(api.requests, hasLength(2));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'YTD'))
            .selected,
        isTrue,
      );
      await range(tester, '1Y');
      expect(api.requests.map((r) => r.range), ['max', 'ytd', '1y']);
      await destination(tester, 'overview');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1Y'))
            .selected,
        isTrue,
      );
      await destination(tester, 'investedEarned');
      expect(api.requests, hasLength(3));
      expect(api.details, 3);
    },
  );

  testWidgets('drag selection is retained on navigation and Android Back', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await destination(tester, 'investedEarned');
    final plot = find.byKey(const ValueKey('invested-earned-plot'));
    final rect = tester.getRect(plot);
    await tester.dragFrom(
      Offset(rect.right - 15, rect.center.dy),
      Offset(-rect.width + 30, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 11.00 EUR'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await destination(tester, 'overview');
    await destination(tester, 'investedEarned');
    expect(find.text('Portfolio Value: 11.00 EUR'), findsOneWidget);
    await section(tester, 'settings');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 11.00 EUR'), findsOneWidget);
    expect(api.requests, hasLength(1));
  });

  testWidgets('account change hides old money and uses profile base currency', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await destination(tester, 'investedEarned');
    api.delay = true;
    await account(tester, 'Account A');
    expect(api.requests.last.account, 'account-a');
    expect(find.text('Portfolio Value: 13.00 EUR').hitTestable(), findsNothing);
    api.requests.last.result.complete(money(100));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 103.00 EUR'), findsOneWidget);
    expect(find.text('Account: Account A'), findsOneWidget);
    expect(find.textContaining('GBP'), findsNothing);
    await account(tester, 'All accounts');
    expect(api.requests.last.account, isNull);
    api.requests.last.result.complete(money(20));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 23.00 EUR'), findsOneWidget);
  });

  testWidgets('refresh ignores late overlapping responses', (tester) async {
    final api = Api();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await destination(tester, 'investedEarned');
    api.delay = true;
    await refresh(tester);
    final first = api.requests.last;
    await refresh(tester);
    final latest = api.requests.last;
    expect(api.requests, hasLength(3));
    expect(first.range, 'max');
    latest.result.complete(money(200));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 203.00 EUR'), findsOneWidget);
    first.result.complete(money(900));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 203.00 EUR'), findsOneWidget);
    expect(find.textContaining('903.00'), findsNothing);
  });

  testWidgets('late range response cannot replace a newer account response', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await destination(tester, 'investedEarned');
    api.delay = true;
    final chip = find.widgetWithText(ChoiceChip, 'YTD');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final oldRange = api.requests.last;
    expect(oldRange.range, 'ytd');
    await account(tester, 'Account B');
    expect(api.requests.last.account, 'account-b');
    expect(api.requests.last.range, 'ytd');
    api.requests.last.result.complete(money(300));
    await tester.pumpAndSettle();
    oldRange.result.complete(money(900));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio Value: 303.00 EUR'), findsOneWidget);
    expect(find.textContaining('903.00'), findsNothing);
  });

  for (final changeServer in [false, true]) {
    testWidgets(
      'session change isolates pending history: server=$changeServer',
      (tester) async {
        final api = Api();
        await tester.pumpWidget(app(api));
        await tester.pumpAndSettle();
        await destination(tester, 'investedEarned');
        await range(tester, 'YTD');
        await account(tester, 'Account A');
        await tester.pumpAndSettle();
        api.delay = true;
        await refresh(tester);
        final old = api.requests.last;
        await tester.pumpWidget(
          app(
            api,
            jwt: changeServer ? 'old' : 'new',
            server: changeServer
                ? 'https://new.example.test'
                : 'https://example.test',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final current = api.requests.last;
        expect(current.account, isNull);
        expect(current.range, 'max');
        current.result.complete(money(400));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
        expect(
          find.byType(InteractiveInvestedEarnedChart, skipOffstage: false),
          findsNothing,
        );
        old.result.complete(money(900));
        await tester.pumpAndSettle();
        await destination(tester, 'investedEarned');
        expect(
          find.text('Portfolio Value: 403.00 ${changeServer ? 'EUR' : 'USD'}'),
          findsOneWidget,
        );
        expect(find.textContaining('903.00'), findsNothing);
        expect(find.text('Account: Account A'), findsNothing);
      },
    );
  }

  testWidgets(
    'restricted history error replaces old chart and refresh recovers',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(app(api));
      await tester.pumpAndSettle();
      await destination(tester, 'investedEarned');
      api.historyFailure = true;
      await refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Historical access restricted'), findsOneWidget);
      expect(find.byType(InteractiveInvestedEarnedChart), findsNothing);
      api.historyFailure = false;
      await refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Portfolio Value: 13.00 EUR'), findsOneWidget);
      expect(api.requests, hasLength(3));
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('shell fits narrow screen with large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(Api(), scale: 2, brightness: brightness));
      await tester.pumpAndSettle();
      await destination(tester, 'investedEarned');
      await tester.ensureVisible(
        find.byKey(const ValueKey('evolution-selected-value')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
