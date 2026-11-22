import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
    await tester.drag(find.text('Portfolio value'), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('holdings-page')), findsOneWidget);
    expect(find.text('Overview'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Portfolio remains the selected root destination.
    expect(
      (tester.widget<NavigationBar>(find.byType(NavigationBar))).selectedIndex,
      1,
    );

    // Swipe left from Portfolio to Activity.
    await tester.drag(find.text('Holdings (0)'), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);

    // Swipe left from Activity into More.
    await tester.dragFrom(const Offset(350, 140), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Swipe right from More back to Activity.
    await tester.dragFrom(const Offset(350, 140), const Offset(350, 0));
    await tester.pumpAndSettle();

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
}
