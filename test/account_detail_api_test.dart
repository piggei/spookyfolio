import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  const accountId = '11111111-2222-3333-4444-555555555555';
  const serverUrl = 'https://ghostfol.io';

  test('fetches account details without changing currencies', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/accounts/$accountId');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['authorization'], 'Bearer jwt-test');
        expect(request.followRedirects, false);

        return http.Response(
          jsonEncode({
            'id': accountId,
            'name': 'Brokerage',
            'currency': 'USD',
            'balance': 1250.75,
            'valueInBaseCurrency': 4321.25,
            'allocationInPercentage': 0.4,
            'activitiesCount': 12,
            'platform': {'name': 'Broker'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final account = await api.getAccountById(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      accountId: accountId,
    );

    expect(account.id, accountId);
    expect(account.name, 'Brokerage');
    expect(account.currency, 'USD');
    expect(account.balance, 1250.75);
    expect(account.value, 4321.25);
    expect(account.allocation, 0.4);
    expect(account.activitiesCount, 12);
    expect(account.platformName, 'Broker');
  });

  test('fetches account balance history with original values', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/api/v1/accounts/$accountId/balances');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['authorization'], 'Bearer jwt-test');

        return http.Response(
          jsonEncode({
            'balances': [
              {
                'id': 'balance-1',
                'accountId': accountId,
                'date': '2026-11-20T00:00:00.000Z',
                'value': 1000.25,
                'valueInBaseCurrency': 920.5,
                'comment': 'Opening balance',
              },
              {
                'id': 'balance-2',
                'accountId': accountId,
                'date': '2026-11-21T00:00:00.000Z',
                'value': 1100.25,
                'valueInBaseCurrency': 1010.5,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.getAccountBalances(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      accountId: accountId,
    );

    expect(result.balances, hasLength(2));
    expect(result.balances.first.accountId, accountId);
    expect(result.balances.first.value, 1000.25);
    expect(result.balances.first.valueInBaseCurrency, 920.5);
    expect(result.balances.first.comment, 'Opening balance');
    expect(result.balances.first.date.isUtc, isTrue);
    expect(result.balances.last.comment, isNull);
  });

  test('preserves restricted or missing monetary values', () {
    final balance = PortfolioAccountBalance.fromJson({
      'id': 'balance-1',
      'accountId': accountId,
      'date': '2026-11-20',
      'value': null,
      'valueInBaseCurrency': null,
    });

    expect(balance.value, isNull);
    expect(balance.valueInBaseCurrency, isNull);
    expect(balance.comment, isNull);
  });

  test('accepts empty balance history', () {
    final result = PortfolioAccountBalances.fromJson({'balances': []});

    expect(result.balances, isEmpty);
  });

  test('rejects malformed balance responses', () {
    expect(() => PortfolioAccountBalances.fromJson({}), throwsFormatException);
    expect(
      () => PortfolioAccountBalances.fromJson({
        'balances': [42],
      }),
      throwsFormatException,
    );
    expect(
      () => PortfolioAccountBalance.fromJson({
        'id': 'balance-1',
        'accountId': accountId,
        'date': 'not-a-date',
        'value': 100,
      }),
      throwsFormatException,
    );
    expect(
      () => PortfolioAccountBalance.fromJson({
        'id': 'balance-1',
        'accountId': accountId,
        'date': '2026-11-20',
        'value': '100',
      }),
      throwsFormatException,
    );
    expect(
      () => PortfolioAccountBalance.fromJson({
        'id': 'balance-1',
        'accountId': accountId,
        'date': '2026-11-20',
        'comment': 42,
      }),
      throwsFormatException,
    );
  });

  test('rejects invalid account identifiers before network access', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Network must not be called');
      }),
    );

    for (final accountId in ['', 'invalid', '../accounts']) {
      await expectLater(
        api.getAccountById(
          serverUrl: serverUrl,
          jwt: 'jwt',
          accountId: accountId,
        ),
        throwsFormatException,
      );

      await expectLater(
        api.getAccountBalances(
          serverUrl: serverUrl,
          jwt: 'jwt',
          accountId: accountId,
        ),
        throwsFormatException,
      );
    }
  });

  test('propagates authorization errors', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async => http.Response('', 403)),
    );

    await expectLater(
      api.getAccountBalances(
        serverUrl: serverUrl,
        jwt: 'jwt',
        accountId: accountId,
      ),
      throwsA(
        isA<PortfolioApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('rejects balance records belonging to another account', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        return http.Response(
          jsonEncode({
            'balances': [
              {
                'id': 'balance-1',
                'accountId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
                'date': '2026-11-20',
                'value': 100,
                'valueInBaseCurrency': 100,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.getAccountBalances(
        serverUrl: serverUrl,
        jwt: 'jwt',
        accountId: accountId,
      ),
      throwsFormatException,
    );
  });
}
