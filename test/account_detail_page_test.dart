import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/account_detail_page.dart';
import 'package:spookyfolio/accounts_page.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

const accountId = '11111111-2222-3333-4444-555555555555';
const serverUrl = 'https://ghostfol.io';

const account = PortfolioAccount(
  id: accountId,
  name: 'Brokerage',
  currency: 'USD',
  balance: 1250.75,
  value: 4321.25,
  platformName: 'Test Broker',
  allocation: 0.4,
  activitiesCount: 2,
  dividends: 40.5,
);

class FakeAccountClient extends PortfolioClient {
  bool paginatedActivities = false;
  int catalogCalls = 0;
  int detailCalls = 0;
  int balanceCalls = 0;
  int activityCalls = 0;
  final activityOffsets = <int>[];
  final activityAccountIds = <String>[];

  @override
  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async {
    catalogCalls++;
    return const PortfolioAccountsCatalog([account]);
  }

  @override
  Future<PortfolioAccount> getAccountById({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async {
    detailCalls++;
    if (accountId != account.id) {
      throw const FormatException('Unexpected account');
    }
    return account;
  }

  @override
  Future<PortfolioAccountBalances> getAccountBalances({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async {
    balanceCalls++;
    if (accountId != account.id) {
      throw const FormatException('Unexpected account');
    }
    return PortfolioAccountBalances([
      PortfolioAccountBalance(
        id: 'balance-1',
        accountId: accountId,
        date: DateTime.utc(2026, 11, 20),
        value: 1000.25,
        valueInBaseCurrency: 920.5,
        comment: 'Opening balance',
      ),
    ]);
  }

  @override
  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    if (take == 100) {
      // Financial-summary pagination is independent of the Activity feed.
      // These navigation tests do not provide financial summary fixtures.
      return const ActivityBatch(activities: [], count: 0);
    }
    activityCalls++;
    activityOffsets.add(skip);
    activityAccountIds.add(accountId);

    if (accountId != account.id) {
      throw const FormatException('Unexpected activity account');
    }

    if (paginatedActivities) {
      if (skip == 0 || skip == 1) {
        final number = skip + 1;

        return ActivityBatch(
          activities: [
            PortfolioActivity.fromJson({
              'id': 'activity-$number',
              'date': number == 1 ? '2026-11-20' : '2026-11-21',
              'type': 'BUY',
              'currency': 'USD',
              'quantity': 1,
              'unitPrice': 100,
              'fee': 0,
              'value': 100,
              'assetProfile': {
                'name': 'Asset $number',
                'symbol': 'ASSET$number',
              },
            }),
          ],
          count: 2,
        );
      }

      return const ActivityBatch(activities: [], count: 2);
    }

    return const ActivityBatch(activities: [], count: 0);
  }
}

Widget detailApp(FakeAccountClient api) => MaterialApp(
  home: AccountDetailPage(
    account: account,
    baseCurrency: 'EUR',
    serverUrl: serverUrl,
    jwt: 'jwt-test',
    client: api,
  ),
);

class _DelayedAccountClient extends PortfolioClient {
  _DelayedAccountClient(this.oldResponse, this.newResponse);

  final Completer<PortfolioAccount> oldResponse;
  final Completer<PortfolioAccount> newResponse;
  final requestedSessions = <String>[];

  @override
  Future<PortfolioAccount> getAccountById({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) {
    requestedSessions.add(jwt);

    if (jwt == 'old-session') {
      return oldResponse.future;
    }

    if (jwt == 'new-session') {
      return newResponse.future;
    }

    throw StateError('Unexpected session');
  }
}

class _SwitchingAccountClient extends PortfolioClient {
  final balanceAccountIds = <String>[];

  @override
  Future<PortfolioAccount> getAccountById({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async {
    return PortfolioAccount(
      id: accountId,
      name: accountId == '11111111-2222-3333-4444-555555555555'
          ? 'Brokerage'
          : 'Second account',
      currency: accountId == '11111111-2222-3333-4444-555555555555'
          ? 'USD'
          : 'EUR',
    );
  }

  @override
  Future<PortfolioAccountBalances> getAccountBalances({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async {
    balanceAccountIds.add(accountId);

    return PortfolioAccountBalances([
      PortfolioAccountBalance(
        id: 'balance-$accountId',
        accountId: accountId,
        date: DateTime.utc(2026, 11, 20),
        value: 100,
        comment: accountId == '11111111-2222-3333-4444-555555555555'
            ? 'Balance for first account'
            : 'Balance for second account',
      ),
    ]);
  }
}

class _SwitchingActivityClient extends _SwitchingAccountClient {
  final activityAccountIds = <String>[];

  @override
  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    if (take == 100) {
      return const ActivityBatch(activities: [], count: 0);
    }
    activityAccountIds.add(accountId);

    return ActivityBatch(
      activities: [
        PortfolioActivity.fromJson({
          'id': 'activity-$accountId',
          'date': '2026-11-20',
          'type': 'BUY',
          'currency': 'EUR',
          'quantity': 1,
          'unitPrice': 100,
          'fee': 0,
          'value': 100,
          'assetProfile': {
            'name': accountId == '11111111-2222-3333-4444-555555555555'
                ? 'Asset from first account'
                : 'Asset from second account',
            'symbol': 'TEST',
          },
        }),
      ],
      count: 1,
    );
  }
}

class _FinancialSectionsClient extends FakeAccountClient {
  @override
  Future<PortfolioAccount> getAccountById({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async => PortfolioAccount(
    id: accountId,
    name: 'Brokerage',
    currency: 'USD',
    balance: 1250.75,
    value: 4321.25,
    allocation: 0.4,
    dividends: 40.5,
    interest: 2,
  );

  @override
  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    if (take != 100) {
      return super.getActivitiesForAccount(
        serverUrl: serverUrl,
        jwt: jwt,
        accountId: accountId,
        skip: skip,
        take: take,
      );
    }
    return ActivityBatch(
      activities: [
        PortfolioActivity.fromJson({
          'id': 'buy-fee',
          'date': '2026-11-20',
          'type': 'BUY',
          'accountId': accountId,
          'feeInBaseCurrency': 5,
        }),
        PortfolioActivity.fromJson({
          'id': 'dividend',
          'date': '2026-11-20',
          'type': 'DIVIDEND',
          'accountId': accountId,
          'valueInBaseCurrency': 40.5,
          'taxInBaseCurrency': 10.5,
        }),
      ],
      count: 2,
    );
  }
}

void main() {
  testWidgets('financial sections retain order and dividend grouping', (
    tester,
  ) async {
    final client = _FinancialSectionsClient();
    await tester.pumpWidget(detailApp(client));
    await tester.pumpAndSettle();

    final labels = [
      'Account details',
      'Fees paid',
      'Trading fees',
      'Interest',
      'Interest received',
      'Dividends',
      'Gross dividends',
      'Of which taxes',
      'Net dividends',
    ];

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    final positions = labels
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList();

    for (var i = 1; i < positions.length; i++) {
      expect(positions[i], greaterThan(positions[i - 1]));
    }

    expect(find.text('40.50 EUR'), findsOneWidget);
    expect(find.text('10.50 EUR'), findsOneWidget);
    expect(find.text('30.00 EUR'), findsOneWidget);
  });

  testWidgets('opens account detail and returns to Accounts', (tester) async {
    final api = FakeAccountClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AccountsPage(
          serverUrl: serverUrl,
          jwt: 'jwt-test',
          baseCurrency: 'EUR',
          client: api,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );

    expect(api.catalogCalls, 1);

    await tester.tap(find.text('Brokerage'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountDetailPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-detail-overview')),
      findsOneWidget,
    );
    expect(api.detailCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AccountDetailPage), findsNothing);
    expect(
      find.byKey(const ValueKey('accounts-overview-page')),
      findsOneWidget,
    );

    expect(api.catalogCalls, 1);
  });

  testWidgets('overview preserves account and base currencies', (tester) async {
    final api = FakeAccountClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(find.text('1250.75 USD'), findsOneWidget);
    expect(find.text('4321.25 EUR'), findsOneWidget);
    expect(find.text('40.50 EUR'), findsOneWidget);
    expect(find.text('40.00%'), findsOneWidget);
    expect(find.text('Test Broker'), findsOneWidget);

    expect(api.detailCalls, 1);
    expect(api.balanceCalls, 0);
    expect(api.activityCalls, 0);
  });

  testWidgets('balances load lazily and are not fetched twice', (tester) async {
    final api = FakeAccountClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(api.balanceCalls, 0);

    await tester.tap(find.text('Balances').last);
    await tester.pumpAndSettle();

    expect(api.balanceCalls, 1);
    expect(
      find.byKey(const ValueKey('account-detail-balances')),
      findsOneWidget,
    );

    expect(find.text('1000.25 USD'), findsOneWidget);
    expect(find.text('920.50 EUR'), findsOneWidget);
    expect(find.text('Opening balance'), findsOneWidget);

    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Balances').last);
    await tester.pumpAndSettle();

    expect(api.balanceCalls, 1);
  });

  testWidgets('Activity uses selected account and loads lazily', (
    tester,
  ) async {
    final api = FakeAccountClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(api.activityCalls, 0);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activity-page')), findsOneWidget);

    expect(api.activityCalls, 1);
    expect(api.activityAccountIds, [accountId]);
    expect(api.activityOffsets, [0]);

    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(api.activityCalls, 1);
  });

  testWidgets('Activity pagination survives account detail navigation', (
    tester,
  ) async {
    final api = FakeAccountClient()..paginatedActivities = true;

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(api.activityOffsets, [0]);
    expect(find.text('Asset 1'), findsOneWidget);

    await tester.tap(find.text('Load more (1 of 2)'));
    await tester.pumpAndSettle();

    expect(api.activityOffsets, [0, 1]);
    expect(find.text('Asset 1'), findsOneWidget);
    expect(find.text('Asset 2'), findsOneWidget);

    await tester.tap(find.text('Balances').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(api.activityOffsets, [0, 1]);
    expect(api.activityCalls, 2);
    expect(find.text('Asset 1'), findsOneWidget);
    expect(find.text('Asset 2'), findsOneWidget);
  });

  testWidgets('refresh affects only the active account section', (
    tester,
  ) async {
    final api = FakeAccountClient();

    await tester.pumpWidget(detailApp(api));
    await tester.pumpAndSettle();

    expect(api.detailCalls, 1);
    expect(api.balanceCalls, 0);
    expect(api.activityCalls, 0);

    // Refresh Overview.
    await tester.tap(find.byTooltip('Refresh account section'));
    await tester.pumpAndSettle();

    expect(api.detailCalls, 2);
    expect(api.balanceCalls, 0);
    expect(api.activityCalls, 0);

    // Open and refresh Balances.
    await tester.tap(find.text('Balances').last);
    await tester.pumpAndSettle();

    expect(api.balanceCalls, 1);

    await tester.tap(find.byTooltip('Refresh account section'));
    await tester.pumpAndSettle();

    expect(api.detailCalls, 2);
    expect(api.balanceCalls, 2);
    expect(api.activityCalls, 0);

    // Open and refresh Activity.
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(api.activityCalls, 1);

    await tester.tap(find.byTooltip('Refresh account section'));
    await tester.pumpAndSettle();

    expect(api.detailCalls, 2);
    expect(api.balanceCalls, 2);
    expect(api.activityCalls, 2);
    expect(api.activityOffsets, [0, 0]);
    expect(api.activityAccountIds, [accountId, accountId]);
  });

  testWidgets('stale account response cannot replace a new session', (
    tester,
  ) async {
    final oldResponse = Completer<PortfolioAccount>();
    final newResponse = Completer<PortfolioAccount>();
    final api = _DelayedAccountClient(oldResponse, newResponse);

    Widget app(String jwt) => MaterialApp(
      home: AccountDetailPage(
        account: account,
        baseCurrency: 'EUR',
        serverUrl: serverUrl,
        jwt: jwt,
        client: api,
      ),
    );

    await tester.pumpWidget(app('old-session'));
    await tester.pump();

    expect(api.requestedSessions, ['old-session']);

    // Reuse the same widget State with a different session.
    await tester.pumpWidget(app('new-session'));
    await tester.pump();

    expect(api.requestedSessions, ['old-session', 'new-session']);

    newResponse.complete(
      const PortfolioAccount(
        id: accountId,
        name: 'Current account',
        currency: 'EUR',
        balance: 250,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Current account'), findsOneWidget);
    expect(find.text('250.00 EUR'), findsOneWidget);

    // The previous session finishes after the new one.
    oldResponse.complete(
      const PortfolioAccount(
        id: accountId,
        name: 'Stale account',
        currency: 'USD',
        balance: 999,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Current account'), findsOneWidget);
    expect(find.text('250.00 EUR'), findsOneWidget);
    expect(find.text('Stale account'), findsNothing);
    expect(find.text('999.00 USD'), findsNothing);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('switching accounts invalidates balance history', (tester) async {
    const secondId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

    const secondAccount = PortfolioAccount(
      id: secondId,
      name: 'Second account',
      currency: 'EUR',
      balance: 500,
    );

    final api = _SwitchingAccountClient();

    Widget app(PortfolioAccount selected) => MaterialApp(
      home: AccountDetailPage(
        account: selected,
        baseCurrency: 'EUR',
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        client: api,
      ),
    );

    await tester.pumpWidget(app(account));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Balances').last);
    await tester.pumpAndSettle();

    expect(find.text('Balance for first account'), findsOneWidget);
    expect(api.balanceAccountIds, [accountId]);

    await tester.pumpWidget(app(secondAccount));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    expect(
      find.byKey(const ValueKey('account-detail-overview')),
      findsOneWidget,
    );

    await tester.tap(find.text('Balances').last);
    await tester.pumpAndSettle();

    expect(find.text('Balance for second account'), findsOneWidget);
    expect(find.text('Balance for first account'), findsNothing);

    expect(api.balanceAccountIds, [accountId, secondId]);
  });

  testWidgets('switching accounts resets Activity data', (tester) async {
    const secondId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

    const secondAccount = PortfolioAccount(
      id: secondId,
      name: 'Second account',
      currency: 'EUR',
    );

    final api = _SwitchingActivityClient();

    Widget app(PortfolioAccount selected) => MaterialApp(
      home: AccountDetailPage(
        account: selected,
        baseCurrency: 'EUR',
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        client: api,
      ),
    );

    await tester.pumpWidget(app(account));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Asset from first account'), findsOneWidget);
    expect(api.activityAccountIds, [accountId]);

    await tester.pumpWidget(app(secondAccount));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Asset from second account'), findsOneWidget);
    expect(find.text('Asset from first account'), findsNothing);
    expect(api.activityAccountIds, [accountId, secondId]);
  });
}
