import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test('activity API uses Bearer and upstream pagination', () async {
    final client = PortfolioClient(
      clientFactory: () => MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/api/v1/activities');
        expect(req.url.queryParameters, {
          'skip': '40',
          'take': '40',
          'sortColumn': 'date',
          'sortDirection': 'desc',
        });
        expect(req.headers['authorization'], 'Bearer jwt-test');
        expect(req.followRedirects, isFalse);
        return http.Response(
          jsonEncode({
            'count': 41,
            'activities': [
              {
                'id': 'item-41',
                'date': '2026-06-08',
                'type': 'BUY',
                'quantity': 2,
                'unitPrice': 161.61,
                'fee': 0,
                'currency': 'EUR',
                'value': 323.22,
                'assetProfile': {'name': 'ETF', 'symbol': 'VWCE.MI'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final result = await client.getActivities(
      serverUrl: 'https://ghostfol.io',
      jwt: 'jwt-test',
      skip: 40,
      take: 40,
    );
    expect(result.count, 41);
    expect(result.activities.single.value, 323.22);
  });

  test('rejects invalid paging without sending network request', () async {
    final client = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Must not issue network request');
      }),
    );
    await expectLater(
      client.getActivities(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        skip: -1,
      ),
      throwsFormatException,
    );
    await expectLater(
      client.getActivities(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        take: 101,
      ),
      throwsFormatException,
    );
  });
}
