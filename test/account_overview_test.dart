import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  const id = '11111111-2222-3333-4444-555555555555';

  test(
    'account overview uses server aggregates without currency conversion',
    () async {
      final api = PortfolioClient(
        clientFactory: () => MockClient((request) async {
          expect(request.url.path, '/api/v1/accounts');
          return http.Response(
            jsonEncode({
              'accounts': [
                {
                  'id': id,
                  'name': 'Savings',
                  'currency': 'USD',
                  'balance': 500,
                  'valueInBaseCurrency': 1234.5,
                  'allocationInPercentage': 0.25,
                  'activitiesCount': 7,
                  'dividendInBaseCurrency': 40.5,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final account = (await api.getAccountsCatalog(
        serverUrl: 'https://ghostfol.io',
        jwt: 'test',
      )).accounts.single;
      expect(account.currency, 'USD');
      expect(account.balance, 500);
      expect(account.value, 1234.5);
      expect(account.allocation, 0.25);
      expect(account.activitiesCount, 7);
      expect(account.dividends, 40.5);
    },
  );

  test('account overview preserves redacted aggregate values', () {
    final account = PortfolioAccount.fromJson({
      'id': id,
      'name': 'Restricted',
      'currency': 'EUR',
      'balance': null,
      'valueInBaseCurrency': null,
      'allocationInPercentage': null,
      'dividendInBaseCurrency': null,
    });
    expect(account.balance, isNull);
    expect(account.value, isNull);
    expect(account.allocation, isNull);
    expect(account.dividends, isNull);
    expect(account.activitiesCount, isNull);
  });

  test('account overview rejects invalid activity counters', () {
    expect(
      () => PortfolioAccount.fromJson({
        'id': id,
        'name': 'Bad',
        'currency': 'EUR',
        'activitiesCount': -1,
      }),
      throwsFormatException,
    );
  });
}
