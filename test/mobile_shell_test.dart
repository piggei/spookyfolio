import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_feed.dart';
import 'package:spookyfolio/mobile_shell.dart';
import 'package:spookyfolio/app_version_title.dart';
import 'package:spookyfolio/return_chart.dart';
import 'package:spookyfolio/portfolio_client.dart';
import 'package:spookyfolio/activity_models.dart';

class _FakePortfolioClient extends PortfolioClient {
  int profiles = 0;
  int details = 0;
  int catalogs = 0;
  int activities = 0;
  bool failProfile = false;
  bool failAccounts = false;
  bool failActivity = false;
  final ranges = <String?>[];

  @override
  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async {
    catalogs++;
    if (failAccounts) throw const PortfolioApiException('Accounts failed');
    return const PortfolioAccountsCatalog([]);
  }

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    activities++;
    if (failActivity) throw const PortfolioApiException('Activity failed');
    return const ActivityBatch(activities: [], count: 0);
  }

  @override
  Future<GhostfolioProfile> getProfile({
    required String serverUrl,
    required String jwt,
  }) async {
    profiles++;
    if (failProfile) throw const PortfolioApiException("Profile failed");
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

class _DetailClient extends _FakePortfolioClient {
  static const account = PortfolioAccount(
    id: 'test-account',
    name: 'Brokerage',
    currency: 'EUR',
  );

  @override
  Future<PortfolioSnapshot> getDetails({
    required String serverUrl,
    required String jwt,
  }) async {
    details++;
    return const PortfolioSnapshot(
      holdings: [PortfolioHolding(symbol: 'EUR', name: 'EUR')],
    );
  }

  @override
  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async {
    catalogs++;
    return const PortfolioAccountsCatalog([account]);
  }

  @override
  Future<PortfolioAccount> getAccountById({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async => account;
}

class _FilteredActivityClient extends _DelayedAccountFilterClient {
  final activityAccounts = <String>[];

  @override
  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    activityAccounts.add(accountId);
    return const ActivityBatch(activities: [], count: 0);
  }
}

class _InFlightClient extends _FakePortfolioClient {
  final oldProfile = Completer<GhostfolioProfile>();
  final detailSessions = <String>[];
  final historySessions = <String>[];

  @override
  Future<GhostfolioProfile> getProfile({
    required String serverUrl,
    required String jwt,
  }) {
    if (jwt == 'old') return oldProfile.future;
    return super.getProfile(serverUrl: serverUrl, jwt: jwt);
  }

  @override
  Future<PortfolioSnapshot> getDetails({
    required String serverUrl,
    required String jwt,
  }) async {
    detailSessions.add('$serverUrl|$jwt');
    return PortfolioSnapshot(
      holdings: [PortfolioHolding(symbol: jwt, name: jwt)],
    );
  }

  @override
  Future<PortfolioHistory> getHistory({
    required String serverUrl,
    required String jwt,
    String? range,
  }) async {
    historySessions.add('$serverUrl|$jwt');
    return const PortfolioHistory([]);
  }
}

Widget _app(
  PortfolioClient api, {
  String jwt = 'jwt-test',
  String server = 'https://ghostfol.io',
}) => MaterialApp(
  home: MobileShell(
    serverUrl: server,
    jwt: jwt,
    client: api,
    onSignOut: () async {},
  ),
);

Future<void> _section(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('main-navigation')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('section-${name.toLowerCase()}')));
  await tester.pumpAndSettle();
}

Future<void> _destination(WidgetTester tester, String name) async {
  final destination = find.byKey(ValueKey('destination-${name.toLowerCase()}'));
  await tester.ensureVisible(destination);
  await tester.pumpAndSettle();
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

Future<void> _refresh(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('main-navigation')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('refresh-navigation')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AppBar preserves its title and opens the menu with the three-dot icon',
    (tester) async {
      await tester.pumpWidget(_app(_FakePortfolioClient()));
      await tester.pumpAndSettle();

      void expectAppBar() {
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.title, isA<AppVersionTitle>());
        expect(find.textContaining('Spookyfolio'), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
        final trigger = find.byKey(const ValueKey('main-navigation'));
        final button = tester.widget<IconButton>(trigger);
        expect((button.icon as Icon).icon, Icons.more_vert);
        expect(
          find.descendant(
            of: find.byType(AppVersionTitle),
            matching: find.byType(TextButton),
          ),
          findsNothing,
        );
        expect(appBar.actions!.last, isA<MenuAnchor>());
        expect(find.byTooltip('Navigation menu'), findsOneWidget);
      }

      expectAppBar();
      expect(find.text('Dashboard'), findsNothing);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-dashboard')), findsOneWidget);
      expect(find.byKey(const ValueKey('section-portfolio')), findsOneWidget);
      expect(find.byKey(const ValueKey('section-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('refresh-navigation')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('section-portfolio')));
      await tester.pumpAndSettle();
      expectAppBar();
      expect(find.text('Portfolio'), findsNothing);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        bar.destinations.cast<NavigationDestination>().map(
          (destination) => destination.label,
        ),
        ['Holdings', 'Accounts', 'Activity'],
      );
      expect(
        bar.destinations.cast<NavigationDestination>().map(
          (destination) => (destination.icon as Icon).icon,
        ),
        [
          Icons.account_balance_wallet_outlined,
          Icons.account_balance_outlined,
          Icons.swap_horiz,
        ],
      );
      await _section(tester, 'Settings');
      expectAppBar();
      final settingsBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(
        settingsBar.destinations.cast<NavigationDestination>().map(
          (destination) => destination.label,
        ),
        ['Preferences', 'About'],
      );
      await _section(tester, 'Dashboard');
      expectAppBar();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .cast<NavigationDestination>()
            .map((destination) => destination.label),
        ['Overview', 'Allocations'],
      );
    },
  );

  testWidgets('dropdown lists implemented sections and marks selection', (
    tester,
  ) async {
    final api = _FakePortfolioClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('main-navigation')));
    await tester.pumpAndSettle();
    for (final name in ['dashboard', 'portfolio', 'settings']) {
      expect(find.byKey(ValueKey('section-$name')), findsOneWidget);
    }
    final selected = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('section-dashboard')),
    );
    expect(selected.trailingIcon, isNotNull);
    expect(find.text('Refresh'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('section-portfolio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    expect(find.text('Holdings'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('main-navigation')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey('section-portfolio')),
          )
          .trailingIcon,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('section-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    await _destination(tester, 'About');
    expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
    await _destination(tester, 'Preferences');
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(api.profiles, 1);
    expect(api.details, 1);
    expect(api.catalogs, 0);
    expect(api.activities, 0);
  });

  testWidgets('secondary selection and swipes stay synchronized', (
    tester,
  ) async {
    final api = _FakePortfolioClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await _section(tester, 'Portfolio');
    final pages = find.byKey(const ValueKey('portfolio-swipe-pages'));
    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.drag(pages, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await _destination(tester, 'Holdings');
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await _section(tester, 'Settings');
    await tester.drag(
      find.byKey(const ValueKey('settings-swipe-pages')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.drag(
      find.byKey(const ValueKey('settings-swipe-pages')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(api.profiles, 1);
    expect(api.details, 1);
  });

  testWidgets('subsection follows finger before release', (tester) async {
    await tester.pumpWidget(_app(_FakePortfolioClient()));
    await tester.pumpAndSettle();
    await _section(tester, 'Portfolio');
    final pages = find.byKey(const ValueKey('portfolio-swipe-pages'));
    final gesture = await tester.startGesture(tester.getCenter(pages));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    final page = tester
        .widget<PageView>(
          find.descendant(of: pages, matching: find.byType(PageView)),
        )
        .controller!
        .page!;
    expect(page, greaterThan(0));
    expect(page, lessThan(1));
    await gesture.moveBy(const Offset(-500, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );
  });

  testWidgets('Android Back restores previous section and subsection', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakePortfolioClient()));
    await tester.pumpAndSettle();
    await _section(tester, 'Portfolio');
    await _destination(tester, 'Activity');
    await _section(tester, 'Settings');
    await _destination(tester, 'About');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(
      tester
          .widget<PopScope>(
            find.byWidgetPredicate((widget) => widget is PopScope),
          )
          .canPop,
      isTrue,
    );
    await _section(tester, 'Portfolio');
    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);
    await _section(tester, 'Settings');
    expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
  });

  testWidgets(
    'repeated section changes restore remembered subsections on Back',
    (tester) async {
      final api = _FakePortfolioClient();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await _section(tester, 'Portfolio');
      await _destination(tester, 'Accounts');
      await _section(tester, 'Settings');
      await _destination(tester, 'About');
      await _section(tester, 'Portfolio');
      expect(
        find.byKey(const ValueKey('accounts-overview-page')),
        findsOneWidget,
      );
      await _destination(tester, 'Activity');
      // Selecting the current section must not add a Back entry.
      await _section(tester, 'Portfolio');
      await _section(tester, 'Settings');
      expect(find.byKey(const ValueKey('about-page')), findsOneWidget);
      await _destination(tester, 'Preferences');

      // Each section restores its latest subsection, including repeated history entries.
      for (final pageKey in [
        'activity-page',
        'settings-page',
        'activity-page',
        'overview-page',
      ]) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(pageKey)), findsOneWidget);
      }
      expect(
        tester
            .widget<PopScope>(
              find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .canPop,
        isTrue,
      );

      // Explicit Dashboard navigation clears history without clearing subsection choices.
      await _section(tester, 'Portfolio');
      expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);
      await _section(tester, 'Settings');
      expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
      await _section(tester, 'Dashboard');
      expect(
        tester
            .widget<PopScope>(
              find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .canPop,
        isTrue,
      );
      expect(api.profiles, 1);
      expect(api.catalogs, 1);
      expect(api.activities, 1);
    },
  );

  testWidgets(
    'Android Back closes dropdown before leaving the current section',
    (tester) async {
      await tester.pumpWidget(_app(_FakePortfolioClient()));
      await tester.pumpAndSettle();
      await _section(tester, 'Portfolio');
      await tester.tap(find.byKey(const ValueKey('main-navigation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-dashboard')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-dashboard')), findsNothing);
      expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    },
  );

  testWidgets('M5 range selector requests selected API range', (tester) async {
    final api = _FakePortfolioClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'YTD'));
    await tester.pumpAndSettle();
    expect(api.ranges, ['max', 'ytd']);
    await _section(tester, 'Portfolio');
    await _section(tester, 'Settings');
    await _section(tester, 'Dashboard');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'YTD'))
          .selected,
      isTrue,
    );
    expect(api.ranges, ['max', 'ytd']);
    await _refresh(tester);
    expect(api.ranges, ['max', 'ytd', 'ytd']);
  });

  testWidgets('chart horizontal drag retains Dashboard', (tester) async {
    final api = _FakePortfolioClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    final chart = find.descendant(
      of: find.byType(InteractiveReturnChart),
      matching: find.byType(GestureDetector),
    );
    final rect = tester.getRect(chart);
    await tester.dragFrom(
      Offset(rect.left + 30, rect.center.dy),
      Offset(rect.width - 60, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-selected-value')), findsOneWidget);
    expect(api.profiles, 1);
  });

  testWidgets('Activity pagination survives subsection and section changes', (
    tester,
  ) async {
    final api = _PaginatedActivityClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(api.requestedOffsets, isEmpty);
    await _section(tester, 'Portfolio');
    expect(api.requestedOffsets, isEmpty);
    expect(api.catalogs, 0);
    await _destination(tester, 'Activity');
    expect(api.requestedOffsets, [0]);
    await tester.tap(find.text('Load more (1 of 2)'));
    await tester.pumpAndSettle();
    expect(api.requestedOffsets, [0, 1]);
    expect(find.byType(ActivityCard), findsNWidgets(2));
    await _destination(tester, 'Holdings');
    await _destination(tester, 'Activity');
    await _section(tester, 'Dashboard');
    await _section(tester, 'Settings');
    await _section(tester, 'Portfolio');
    expect(api.requestedOffsets, [0, 1]);
    expect(find.byType(ActivityCard), findsNWidgets(2));
    expect(api.profiles, 1);
    expect(api.details, 1);
    await _refresh(tester);
    expect(api.requestedOffsets, [0, 1, 0]);
    expect(api.profiles, 1);
    expect(api.catalogs, 0);
  });

  testWidgets('dropdown refresh targets only the active data source', (
    tester,
  ) async {
    final api = _FakePortfolioClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await _refresh(tester);
    expect(api.profiles, 2);
    expect(api.catalogs, 0);
    expect(api.activities, 0);
    await _section(tester, 'Portfolio');
    await _destination(tester, 'Accounts');
    expect(api.catalogs, 1);
    await _refresh(tester);
    expect(api.catalogs, 2);
    expect(api.profiles, 2);
    await _destination(tester, 'Activity');
    expect(api.activities, 1);
    await _refresh(tester);
    expect(api.activities, 2);
    expect(api.catalogs, 2);
    expect(api.profiles, 2);
    await _destination(tester, 'Holdings');
    await _refresh(tester);
    expect(api.profiles, 3);
    expect(api.details, 3);
    expect(api.catalogs, 2);
    expect(api.activities, 2);
  });

  testWidgets('Settings does not offer an unrelated portfolio refresh', (
    tester,
  ) async {
    final api = _FakePortfolioClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await _section(tester, 'Settings');
    await tester.tap(find.byKey(const ValueKey('main-navigation')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey('refresh-navigation')),
          )
          .onPressed,
      isNull,
    );
    expect(api.profiles, 1);
    expect(api.catalogs, 0);
    expect(api.activities, 0);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'account filter preserves Accounts during load and retry: $fails',
      (tester) async {
        final api = _DelayedAccountFilterClient()
          ..failFirstFilteredRequest = fails;
        await tester.pumpWidget(_app(api));
        await tester.pumpAndSettle();
        await _section(tester, 'Portfolio');
        await _destination(tester, 'Accounts');
        await tester.tap(find.byTooltip('Select account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test account').last);
        await tester.pump();
        await tester.pump();
        expect(api.filteredRequests, 1);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        if (fails) {
          api.failedDetails.completeError(
            const PortfolioApiException(
              'Simulated server error',
              statusCode: 500,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Could not update portfolio data.'), findsOneWidget);
          await tester.tap(find.text('Retry'));
          await tester.pump();
          expect(api.filteredRequests, 2);
        }
        api.filteredDetails.complete(const PortfolioSnapshot(holdings: []));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('accounts-overview-page')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        await _section(tester, 'Dashboard');
        expect(find.text('Account: Test account'), findsOneWidget);
        await _refresh(tester);
        expect(api.filteredRequests, fails ? 3 : 2);
        await _section(tester, 'Portfolio');
        expect(
          find.byKey(const ValueKey('accounts-overview-page')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('initial error and retry recover without resetting navigation', (
    tester,
  ) async {
    final api = _FakePortfolioClient()..failProfile = true;
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.text('Profile failed'), findsOneWidget);
    await _section(tester, 'Settings');
    api.failProfile = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(api.profiles, 2);
  });

  for (final accounts in [true, false]) {
    testWidgets(
      '${accounts ? "Accounts" : "Activity"} error retry stays local',
      (tester) async {
        final api = _FakePortfolioClient()
          ..failAccounts = accounts
          ..failActivity = !accounts;
        await tester.pumpWidget(_app(api));
        await tester.pumpAndSettle();
        await _section(tester, 'Portfolio');
        await _destination(tester, accounts ? 'Accounts' : 'Activity');
        expect(
          find.text(accounts ? 'Could not load accounts.' : 'Activity failed'),
          findsOneWidget,
        );
        api.failAccounts = false;
        api.failActivity = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(accounts ? 'accounts-overview-page' : 'activity-page'),
          ),
          findsOneWidget,
        );
        expect(api.profiles, 1);
        expect(accounts ? api.catalogs : api.activities, 2);
      },
    );
  }

  testWidgets('nested Holding and Account Back restore their subsection', (
    tester,
  ) async {
    final api = _DetailClient();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await _section(tester, 'Portfolio');
    await tester.tap(find.byKey(const ValueKey('holding-EUR')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holding-cash-page')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await _destination(tester, 'Accounts');
    await tester.tap(find.text('Brokerage'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-detail-overview')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(api.profiles, 1);
    expect(api.catalogs, 1);
  });

  testWidgets(
    'account filter follows Activity refresh and resets on session change',
    (tester) async {
      final api = _FilteredActivityClient();
      api.filteredDetails.complete(const PortfolioSnapshot(holdings: []));
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test account'));
      await tester.pumpAndSettle();
      await _section(tester, 'Portfolio');
      await _destination(tester, 'Activity');
      await _refresh(tester);
      expect(api.activityAccounts, [
        _DelayedAccountFilterClient.accountId,
        _DelayedAccountFilterClient.accountId,
      ]);
      await _section(tester, 'Settings');
      await _section(tester, 'Portfolio');
      expect(api.activityAccounts.length, 2);
      await _section(tester, 'Dashboard');
      expect(find.text('Account: Test account'), findsOneWidget);
      await tester.pumpWidget(_app(api, jwt: 'new-session'));
      await tester.pumpAndSettle();
      expect(find.text('Account: Test account'), findsNothing);
      expect(api.details, 2);
      await _section(tester, 'Portfolio');
      await _destination(tester, 'Activity');
      expect(api.activities, 1);
      expect(api.activityAccounts.length, 2);
    },
  );

  for (final overlay in [
    'menu',
    'account selector',
    'holding detail',
    'account detail',
  ]) {
    testWidgets('session change dismisses old $overlay', (tester) async {
      final api = _DetailClient();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      if (overlay == 'menu') {
        await tester.tap(find.byKey(const ValueKey('main-navigation')));
      } else if (overlay == 'account selector') {
        await tester.tap(find.byTooltip('Select account'));
      } else {
        await _section(tester, 'Portfolio');
        if (overlay == 'holding detail') {
          await tester.tap(find.byKey(const ValueKey('holding-EUR')));
        } else {
          await _destination(tester, 'Accounts');
          await tester.tap(find.text('Brokerage'));
        }
      }
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(api, jwt: 'new-session'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('section-dashboard')), findsNothing);
      expect(find.text('Brokerage'), findsNothing);
      expect(find.byKey(const ValueKey('holding-cash-page')), findsNothing);
      expect(
        find.byKey(const ValueKey('account-detail-overview')),
        findsNothing,
      );
      expect(api.profiles, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'late old-session response cannot overwrite new snapshot or mix credentials',
    (tester) async {
      final api = _InFlightClient();
      await tester.pumpWidget(_app(api, jwt: 'old'));
      await tester.pump();
      await tester.pumpWidget(
        _app(api, jwt: 'new', server: 'https://new.example'),
      );
      await tester.pumpAndSettle();
      await _section(tester, 'Portfolio');
      expect(find.byKey(const ValueKey('holding-new')), findsOneWidget);
      api.oldProfile.complete(
        const GhostfolioProfile(id: 'old-user', baseCurrency: 'USD'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('holding-new')), findsOneWidget);
      expect(find.byKey(const ValueKey('holding-old')), findsNothing);
      expect(api.detailSessions, [
        'https://new.example|new',
        'https://ghostfol.io|old',
      ]);
      expect(api.historySessions, [
        'https://new.example|new',
        'https://ghostfol.io|old',
      ]);
    },
  );

  testWidgets('bottom navigation and title fit a narrow smartphone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_FakePortfolioClient()));
    await tester.pumpAndSettle();
    await _section(tester, 'Portfolio');
    final bar = find.byType(NavigationBar);
    expect(find.byType(TabBar), findsNothing);
    expect(tester.getRect(bar).bottom, 640);
    expect(tester.getRect(bar).top, greaterThan(500));
    expect(find.byType(AppVersionTitle), findsOneWidget);
    await _destination(tester, 'Activity');
    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);
    await _section(tester, 'Settings');
    await _destination(tester, 'About');
    expect(tester.takeException(), isNull);
  });

  for (final changeServer in [false, true]) {
    testWidgets(
      'session ${changeServer ? "server" : "JWT"} resets navigation and pagination',
      (tester) async {
        final api = _PaginatedActivityClient();
        await tester.pumpWidget(_app(api));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'YTD'));
        await tester.pumpAndSettle();
        await _section(tester, 'Portfolio');
        await _destination(tester, 'Activity');
        await tester.tap(find.text('Load more (1 of 2)'));
        await tester.pumpAndSettle();
        final oldState = tester.state(find.byType(ActivityFeed));
        await tester.pumpWidget(
          _app(
            api,
            jwt: changeServer ? 'jwt-test' : 'new-jwt',
            server: changeServer
                ? 'https://new.example'
                : 'https://ghostfol.io',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'MAX'))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<PopScope>(
                find.byWidgetPredicate((widget) => widget is PopScope),
              )
              .canPop,
          isTrue,
        );
        expect(api.ranges, ['max', 'ytd', 'max']);
        await _section(tester, 'Portfolio');
        expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
        await _destination(tester, 'Activity');
        expect(tester.state(find.byType(ActivityFeed)), isNot(same(oldState)));
        expect(api.requestedOffsets, [0, 1, 0]);
        expect(find.byType(ActivityCard), findsOneWidget);
      },
    );
  }
}
