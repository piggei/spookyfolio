import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_feed.dart';
import 'package:spookyfolio/mobile_shell.dart';
import 'package:spookyfolio/return_chart.dart';
import 'package:spookyfolio/portfolio_client.dart';
import 'package:spookyfolio/activity_models.dart';

class _FakePortfolioClient extends PortfolioClient {
  int profiles = 0;
  int details = 0;
  final ranges = <String?>[];

  @override
  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async => const PortfolioAccountsCatalog([]);

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async => const ActivityBatch(activities: [], count: 0);

  @override
  Future<GhostfolioProfile> getProfile({
    required String serverUrl,
    required String jwt,
  }) async {
    profiles++;
    return const GhostfolioProfile(
      id: 'user-id',
      baseCurrency: 'EUR',
      performanceCalculationType: 'ROAI',
    );
  }

  @override
  Future<PortfolioSnapshot> getDetails({
    required String serverUrl,
    required String jwt,
  }) async {
    details++;
    return const PortfolioSnapshot(holdings: []);
  }

  @override
  Future<PortfolioHistory> getHistory({
    required String serverUrl,
    required String jwt,
    String? range,
  }) async {
    ranges.add(range);
    return PortfolioHistory.fromJson({
      'performance': {
        'currentValueInBaseCurrency': 956.10,
        'netPerformanceWithCurrencyEffect': -34.23,
        'netPerformancePercentageWithCurrencyEffect': -0.0713,
      },
      'chart': [
        {
          'date': '2026-11-20',
          'value': null,
          'netPerformanceInPercentageWithCurrencyEffect': 0.05,
        },
        {
          'date': '2026-11-21',
          'value': null,
          'netPerformanceInPercentageWithCurrencyEffect': -0.0713,
        },
      ],
    });
  }
}

class _PaginatedActivityClient extends _FakePortfolioClient {
  final requestedOffsets = <int>[];

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    requestedOffsets.add(skip);

    if (skip >= 2) {
      return const ActivityBatch(activities: [], count: 2);
    }

    return ActivityBatch(
      activities: [
        PortfolioActivity(
          id: 'activity-$skip',
          date: DateTime.utc(2026, 11, 20 - skip),
          type: 'BUY',
          symbol: 'TEST',
          currency: 'EUR',
          quantity: 1,
          unitPrice: 10,
          value: 10,
        ),
      ],
      count: 2,
    );
  }
}

class _DelayedAccountFilterClient extends _FakePortfolioClient {
  static const accountId = '11111111-2222-3333-4444-555555555555';

  final filteredDetails = Completer<PortfolioSnapshot>();
  final failedDetails = Completer<PortfolioSnapshot>();
  bool failFirstFilteredRequest = false;
  int filteredRequests = 0;

  @override
  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async => const PortfolioAccountsCatalog([
    PortfolioAccount(id: accountId, name: 'Test account', currency: 'EUR'),
  ]);

  @override
  Future<PortfolioSnapshot> getDetailsForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) {
    filteredRequests++;
    expect(accountId, _DelayedAccountFilterClient.accountId);

    if (failFirstFilteredRequest && filteredRequests == 1) {
      return failedDetails.future;
    }

    return filteredDetails.future;
  }

  @override
  Future<PortfolioHistory> getHistoryForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    String? range,
  }) async => const PortfolioHistory([]);
}

void main() {
  testWidgets('M10 navigates across main and contextual destinations', (
    tester,
  ) async {
    final fake = _FakePortfolioClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(fake.profiles, 1);
    expect(fake.details, 1);
    expect(fake.ranges, ['max']);

    await tester.tap(find.text('Portfolio').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );
    expect(find.text('All accounts'), findsNothing);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    await tester.tap(find.text('Holdings').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    await tester.tap(find.text('About').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fake.profiles, 1);
    expect(fake.details, 1);
    expect(fake.ranges, ['max']);
  });

  testWidgets('M5 range selector requests selected API range', (tester) async {
    final fake = _FakePortfolioClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'YTD'));
    await tester.pumpAndSettle();
    expect(fake.ranges, ['max', 'ytd']);
  });

  testWidgets('M10 preserves performance range across Portfolio navigation', (
    tester,
  ) async {
    final fake = _FakePortfolioClient();
    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'YTD'));
    await tester.pumpAndSettle();
    expect(fake.ranges, ['max', 'ytd']);

    await tester.tap(find.text('Portfolio').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'YTD'), findsOneWidget);
    expect(fake.ranges, ['max', 'ytd']);
    expect(fake.profiles, 2);
    expect(fake.details, 2);
  });
  testWidgets('M11 swipes between Holdings and Accounts', (tester) async {
    final fake = _FakePortfolioClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portfolio').last);
    await tester.pumpAndSettle();

    final pages = find.byKey(const ValueKey('portfolio-swipe-pages'));
    expect(pages, findsOneWidget);
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);

    await tester.drag(pages, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );
    expect(
      find.byType(NavigationBar).last.evaluate().single.widget,
      isA<NavigationBar>().having(
        (bar) => bar.selectedIndex,
        'selectedIndex',
        1,
      ),
    );

    await tester.drag(pages, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(fake.profiles, 1);
    expect(fake.details, 1);
    expect(fake.ranges, ['max']);
  });

  testWidgets('M11 swipes between Settings and About', (tester) async {
    final fake = _FakePortfolioClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();

    final pages = find.byKey(const ValueKey('more-swipe-pages'));
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    await tester.drag(pages, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
    expect(find.text('About').first, findsWidgets);

    await tester.drag(pages, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(fake.profiles, 1);
    expect(fake.details, 1);
  });

  testWidgets('root swipe follows hierarchical navigation', (tester) async {
    final fake = _FakePortfolioClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);

    // Swipe left from Overview into Portfolio.
    await tester.dragFrom(const Offset(400, 140), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    expect(find.text('Overview'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Back from Portfolio restores Overview.
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    // Navigate from Overview to Activity using the root menu.
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);

    // Swipe left from Activity into More.
    await tester.dragFrom(const Offset(400, 140), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Back from More restores Activity, without another swipe.
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);

    expect(fake.profiles, 1);
    expect(fake.details, 1);
    expect(fake.ranges, ['max']);
  });

  testWidgets('chart horizontal drag does not change root destination', (
    tester,
  ) async {
    final fake = _FakePortfolioClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = find.descendant(
      of: find.byType(InteractiveReturnChart),
      matching: find.byType(GestureDetector),
    );

    expect(chart, findsOneWidget);

    final rect = tester.getRect(chart);

    await tester.dragFrom(
      Offset(rect.left + 30, rect.center.dy),
      Offset(rect.width - 60, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-selected-value')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    expect(fake.profiles, 1);
    expect(fake.details, 1);
  });

  testWidgets('root PageView follows finger before release', (tester) async {
    final fake = _FakePortfolioClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pages = find.byKey(const ValueKey('root-swipe-pages'));
    expect(pages, findsOneWidget);

    final controller = tester.widget<PageView>(pages).controller!;
    expect(controller.page, 0);

    final gesture = await tester.startGesture(const Offset(400, 140));

    // First movement allows Flutter to resolve the gesture arena.
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    // The next movement must scroll the page while the finger is down.
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();

    final intermediate = controller.page!;

    expect(intermediate, greaterThan(0));
    expect(intermediate, lessThan(1));

    // The contextual route must not open during the drag.
    expect(find.byType(NavigationBar), findsOneWidget);

    await gesture.moveBy(const Offset(-380, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.page, 1);
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
  });

  testWidgets('Activity pagination survives root page navigation', (
    tester,
  ) async {
    final fake = _PaginatedActivityClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Activity loads lazily.
    expect(fake.requestedOffsets, isEmpty);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(fake.requestedOffsets, [0]);
    expect(find.text('Activity (2)'), findsOneWidget);
    expect(find.text('Load more (1 of 2)'), findsOneWidget);

    await tester.tap(find.text('Load more (1 of 2)'));
    await tester.pumpAndSettle();

    expect(fake.requestedOffsets, [0, 1]);
    expect(find.text('Load more (1 of 2)'), findsNothing);
    expect(find.byType(ActivityCard), findsNWidgets(2));

    // Leave Activity and return without refreshing its data.
    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(fake.requestedOffsets, [0, 1]);
    expect(find.text('Activity (2)'), findsOneWidget);
    expect(find.byType(ActivityCard), findsNWidgets(2));

    // Main portfolio data must not be fetched again.
    expect(fake.profiles, 1);
    expect(fake.details, 1);
    expect(fake.ranges, ['max']);
  });

  testWidgets('contextual Back restores origin after direct navigation', (
    tester,
  ) async {
    final fake = _FakePortfolioClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: fake,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> expectRoot(int index, String pageKey) async {
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );

      final pages = find.byKey(const ValueKey('root-swipe-pages'));
      expect(pages, findsOneWidget);

      final controller = tester.widget<PageView>(pages).controller!;
      expect(controller.page, closeTo(index.toDouble(), 0.01));
      expect(find.byKey(ValueKey(pageKey)), findsOneWidget);
    }

    // Jump from Overview to More across intermediate destinations.
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await expectRoot(0, 'overview-page');

    // Open Portfolio directly from Overview.
    await tester.tap(find.text('Portfolio').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await expectRoot(0, 'overview-page');

    // Open More directly from Activity.
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    await expectRoot(2, 'activity-page');

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await expectRoot(2, 'activity-page');

    // Navigation alone must not reload main portfolio data.
    expect(fake.profiles, 1);
    expect(fake.details, 1);
    expect(fake.ranges, ['max']);
  });

  testWidgets('account filter preserves Portfolio Accounts navigation', (
    tester,
  ) async {
    final api = _DelayedAccountFilterClient();

    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt-test',
          client: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portfolio').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    final rootPages = find.byKey(const ValueKey('root-swipe-pages'));
    final portfolioPages = find.byKey(const ValueKey('portfolio-swipe-pages'));

    expect(rootPages, findsOneWidget);
    expect(portfolioPages, findsOneWidget);
    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );

    final rootController = tester.widget<PageView>(rootPages).controller!;
    final portfolioController = tester
        .widget<PageView>(portfolioPages)
        .controller!;

    expect(rootController.page, closeTo(1, 0.01));
    expect(portfolioController.page, closeTo(1, 0.01));

    // Select an account and keep its API response pending.
    await tester.tap(find.byTooltip('Select account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test account').last);
    await tester.pump();
    await tester.pump();

    expect(api.filteredRequests, 1);

    // Navigation must remain mounted during the request.
    expect(rootPages, findsOneWidget);
    expect(portfolioPages, findsOneWidget);

    expect(rootController.page, closeTo(1, 0.01));
    expect(portfolioController.page, closeTo(1, 0.01));

    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar).last)
          .selectedIndex,
      1,
    );

    // Complete the request with the selected account's data.
    api.filteredDetails.complete(const PortfolioSnapshot(holdings: []));

    await tester.pumpAndSettle();

    expect(rootPages, findsOneWidget);
    expect(portfolioPages, findsOneWidget);

    expect(rootController.page, closeTo(1, 0.01));
    expect(portfolioController.page, closeTo(1, 0.01));

    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );

    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar).last)
          .selectedIndex,
      1,
    );

    expect(find.text('Portfolio'), findsOneWidget);
  });

  testWidgets(
    'account filter failure and retry preserve contextual navigation',
    (tester) async {
      final api = _DelayedAccountFilterClient()
        ..failFirstFilteredRequest = true;

      await tester.pumpWidget(
        MaterialApp(
          home: MobileShell(
            serverUrl: 'https://ghostfol.io',
            jwt: 'jwt-test',
            client: api,
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Portfolio').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accounts').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Select account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test account').last);
      await tester.pump();

      expect(api.filteredRequests, 1);

      api.failedDetails.completeError(
        const PortfolioApiException('Simulated server error', statusCode: 500),
      );

      await tester.pumpAndSettle();

      expect(api.filteredRequests, 1);

      final rootPages = find.byKey(const ValueKey('root-swipe-pages'));
      final portfolioPages = find.byKey(
        const ValueKey('portfolio-swipe-pages'),
      );

      // An API error must not dismantle the navigation.
      expect(rootPages, findsOneWidget);
      expect(portfolioPages, findsOneWidget);

      expect(
        tester.widget<PageView>(rootPages).controller!.page,
        closeTo(1, 0.01),
      );
      expect(
        tester.widget<PageView>(portfolioPages).controller!.page,
        closeTo(1, 0.01),
      );

      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar).last)
            .selectedIndex,
        1,
      );

      expect(find.text('Could not update portfolio data.'), findsOneWidget);

      // Retry the failed request.
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(api.filteredRequests, 2);
      expect(rootPages, findsOneWidget);
      expect(portfolioPages, findsOneWidget);

      api.filteredDetails.complete(const PortfolioSnapshot(holdings: []));

      await tester.pumpAndSettle();

      expect(rootPages, findsOneWidget);
      expect(portfolioPages, findsOneWidget);

      expect(
        tester.widget<PageView>(rootPages).controller!.page,
        closeTo(1, 0.01),
      );
      expect(
        tester.widget<PageView>(portfolioPages).controller!.page,
        closeTo(1, 0.01),
      );

      expect(
        find.byKey(const ValueKey('accounts-overview-page')),
        findsOneWidget,
      );

      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar).last)
            .selectedIndex,
        1,
      );
    },
  );

  testWidgets('session change isolates portfolio snapshot', (tester) async {
    final api = _FakePortfolioClient();

    Widget app(String jwt) => MaterialApp(
      home: MobileShell(
        serverUrl: 'https://ghostfol.io',
        jwt: jwt,
        client: api,
        onSignOut: () async {},
      ),
    );

    await tester.pumpWidget(app('first-session'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);

    final previousBuilder = tester.widget<FutureBuilder>(
      find.byWidgetPredicate(
        (widget) =>
            widget is FutureBuilder &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'portfolio-snapshot-',
            ),
      ),
    );

    await tester.pumpWidget(app('second-session'));
    await tester.pump();

    final currentBuilder = tester.widget<FutureBuilder>(
      find.byWidgetPredicate(
        (widget) =>
            widget is FutureBuilder &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'portfolio-snapshot-',
            ),
      ),
    );

    expect(currentBuilder.key, isNot(previousBuilder.key));
    expect(api.profiles, 2);
  });
}
