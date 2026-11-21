import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  const id = '11111111-2222-3333-4444-555555555555';

  test(
    'accounts catalog preserves server fields and null restricted values',
    () async {
      final api = PortfolioClient(
        clientFactory: () => MockClient((req) async {
          expect(req.url.path, '/api/v1/accounts');
          expect(req.url.queryParameters, isEmpty);
          return http.Response(
            jsonEncode({
              'accounts': [
                {
                  'id': id,
                  'name': 'Broker',
                  'currency': 'EUR',
                  'balance': null,
                  'valueInBaseCurrency': null,
                  'platform': {'name': 'Platform'},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final response = await api.getAccountsCatalog(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
      );
      expect(response.accounts.single.name, 'Broker');
      expect(response.accounts.single.balance, isNull);
      expect(response.accounts.single.value, isNull);
      expect(response.accounts.single.platformName, 'Platform');
    },
  );

  test(
    'account filtered details, performance and activity use native API filters',
    () async {
      final seen = <String>[];
      final api = PortfolioClient(
        clientFactory: () => MockClient((req) async {
          expect(req.url.queryParameters['accounts'], id);
          seen.add(req.url.path);
          if (req.url.path == '/api/v1/activities') {
            expect(req.url.queryParameters['skip'], '20');
            expect(req.url.queryParameters['take'], '20');
            return http.Response(
              '{"activities":[],"count":0}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == '/api/v2/portfolio/performance') {
            expect(req.url.queryParameters['range'], 'ytd');
            return http.Response(
              '{"chart":[],"performance":{}}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{"holdings":[],"summary":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await api.getDetailsForAccount(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        accountId: id,
      );
      await api.getHistoryForAccount(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        accountId: id,
        range: 'ytd',
      );
      await api.getActivitiesForAccount(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        accountId: id,
        skip: 20,
        take: 20,
      );
      expect(seen, [
        '/api/v1/portfolio/details',
        '/api/v2/portfolio/performance',
        '/api/v1/activities',
      ]);
    },
  );

  test('invalid account filter is rejected before request', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Network must not be called');
      }),
    );
    await expectLater(
      api.getDetailsForAccount(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        accountId: 'not-an-uuid',
      ),
      throwsFormatException,
    );
  });
}
