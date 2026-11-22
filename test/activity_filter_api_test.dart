import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  const serverUrl = 'https://ghostfol.io';
  const accountId = '11111111-2222-3333-4444-555555555555';

  test('fetches unfiltered activities with server pagination', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/activities');
        expect(request.url.queryParameters, {
          'skip': '40',
          'take': '20',
          'sortColumn': 'date',
          'sortDirection': 'desc',
        });
        expect(request.headers['authorization'], 'Bearer jwt-test');
        expect(request.followRedirects, isFalse);

        return http.Response(
          jsonEncode({'activities': [], 'count': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.getFilteredActivities(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      skip: 40,
      take: 20,
    );

    expect(result.count, 0);
    expect(result.activities, isEmpty);
  });

  test('filters activities by account', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.url.queryParameters['accounts'], accountId);
        expect(request.url.queryParameters.containsKey('symbol'), isFalse);
        expect(request.url.queryParameters.containsKey('dataSource'), isFalse);

        return http.Response(
          jsonEncode({'activities': [], 'count': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.getFilteredActivities(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      accountId: accountId,
    );
  });

  test('filters activities by exact asset identity', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.url.queryParameters['dataSource'], 'YAHOO');
        expect(request.url.queryParameters['symbol'], 'VWCE.MI');
        expect(request.url.queryParameters.containsKey('accounts'), isFalse);

        return http.Response(
          jsonEncode({'activities': [], 'count': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.getFilteredActivities(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      dataSource: 'YAHOO',
      symbol: 'VWCE.MI',
    );
  });

  test('combines account and asset filters with pagination', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/api/v1/activities');
        expect(request.url.queryParameters, {
          'accounts': accountId,
          'dataSource': 'YAHOO',
          'symbol': 'VWCE.MI',
          'skip': '20',
          'take': '20',
          'sortColumn': 'date',
          'sortDirection': 'desc',
        });

        return http.Response(
          jsonEncode({'activities': [], 'count': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.getFilteredActivities(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      accountId: accountId,
      dataSource: 'YAHOO',
      symbol: 'VWCE.MI',
      skip: 20,
      take: 20,
    );
  });

  test('rejects incomplete asset filters without HTTP', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected network request');
      }),
    );

    for (final filters in [
      {'dataSource': 'YAHOO'},
      {'symbol': 'VWCE.MI'},
    ]) {
      await expectLater(
        api.getFilteredActivities(
          serverUrl: serverUrl,
          jwt: 'jwt-test',
          dataSource: filters['dataSource'],
          symbol: filters['symbol'],
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects invalid filter values without HTTP', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected network request');
      }),
    );

    final invalidCalls = [
      () => api.getFilteredActivities(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        accountId: 'invalid',
      ),
      () => api.getFilteredActivities(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        dataSource: 'YAHOO',
        symbol: ' ',
      ),
      () => api.getFilteredActivities(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        dataSource: 'INVALID/SOURCE',
        symbol: 'VWCE.MI',
      ),
      () => api.getFilteredActivities(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        dataSource: 'YAHOO',
        symbol: 'VWCE\nMI',
      ),
      () => api.getFilteredActivities(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        skip: -1,
      ),
      () => api.getFilteredActivities(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        take: 101,
      ),
    ];

    for (final call in invalidCalls) {
      await expectLater(call(), throwsFormatException);
    }
  });

  test('preserves the server-provided result count', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        return http.Response(
          jsonEncode({
            'count': 21,
            'activities': [
              {
                'id': 'activity-1',
                'date': '2026-11-20',
                'type': 'BUY',
                'currency': 'EUR',
                'quantity': 2,
                'unitPrice': 100,
                'fee': 1,
                'value': 200,
                'assetProfile': {'name': 'Example ETF', 'symbol': 'VWCE.MI'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.getFilteredActivities(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      dataSource: 'YAHOO',
      symbol: 'VWCE.MI',
    );

    expect(result.count, 21);
    expect(result.activities, hasLength(1));
    expect(result.activities.single.value, 200);
  });
}
