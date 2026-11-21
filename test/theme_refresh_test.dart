import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/mobile_shell.dart';
import 'package:spookyfolio/portfolio_client.dart';

class _Api extends PortfolioClient {
  int activityCalls = 0;
  int profileCalls = 0;

  @override
  Future<GhostfolioProfile> getProfile({
    required String serverUrl,
    required String jwt,
  }) async {
    profileCalls++;
    return const GhostfolioProfile(id: 'test-user', baseCurrency: 'EUR');
  }

  @override
  Future<PortfolioSnapshot> getDetails({
    required String serverUrl,
    required String jwt,
  }) async => const PortfolioSnapshot(holdings: []);

  @override
  Future<PortfolioHistory> getHistory({
    required String serverUrl,
    required String jwt,
    String? range,
  }) async => const PortfolioHistory([]);

  @override
  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    activityCalls++;
    return const ActivityBatch(activities: [], count: 0);
  }
}

void main() {
  testWidgets('activity tab uses only the AppBar refresh', (tester) async {
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(
        home: MobileShell(
          serverUrl: 'https://ghostfol.io',
          jwt: 'jwt',
          client: api,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(api.activityCalls, 1);
    expect(find.byTooltip('Refresh activities'), findsNothing);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(api.activityCalls, 2);
    expect(api.profileCalls, 1);
  });

  testWidgets('theme choices forward preference to root application', (
    tester,
  ) async {
    final api = _Api();
    final selected = ValueNotifier<ThemeMode>(ThemeMode.system);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: selected,
        builder: (context, mode, _) => MaterialApp(
          themeMode: mode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: MobileShell(
            serverUrl: 'https://ghostfol.io',
            jwt: 'jwt',
            client: api,
            onSignOut: () async {},
            themeMode: mode,
            onThemeChanged: (next) async {
              selected.value = next;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(selected.value, ThemeMode.light);
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(selected.value, ThemeMode.dark);
    selected.dispose();
  });
}
