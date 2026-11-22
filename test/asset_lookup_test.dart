import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/asset_lookup_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  const serverUrl = 'https://ghostfol.io';

  test('parses asset lookup results', () {
    final result = AssetLookupResults.fromJson({
      'items': [
        {
          'symbol': 'VWCE.MI',
          'name': 'Vanguard ETF',
          'currency': 'EUR',
          'dataSource': 'YAHOO',
        },
        {'symbol': 'UNKNOWN', 'currency': 'USD', 'dataSource': null},
      ],
    });

    expect(result.items, hasLength(2));
    expect(result.items.first.symbol, 'VWCE.MI');
    expect(result.items.first.name, 'Vanguard ETF');
    expect(result.items.first.canFilter, isTrue);
    expect(result.items.last.canFilter, isFalse);
    expect(result.items.last.name, isNull);
  });

  test('rejects malformed lookup responses', () {
    for (final json in [
      <String, dynamic>{},
      {'items': 'invalid'},
      {
        'items': [null],
      },
      {
        'items': [
          {'symbol': '', 'currency': 'EUR'},
        ],
      },
      {
        'items': [
          {
            'symbol': 'VWCE.MI',
            'currency': 'EUR',
            'dataSource': 'INVALID/SOURCE',
          },
        ],
      },
    ]) {
      expect(() => AssetLookupResults.fromJson(json), throwsFormatException);
    }
  });

  test('sends authenticated lookup request', () async {
    var calls = 0;

    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        calls++;

        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/symbols/lookup');
        expect(request.url.queryParameters, {'query': 'VWCE.MI'});
        expect(request.headers['authorization'], 'Bearer jwt-test');
        expect(request.followRedirects, isFalse);

        return http.Response(
          jsonEncode({
            'items': [
              {
                'symbol': 'VWCE.MI',
                'name': 'Vanguard ETF',
                'currency': 'EUR',
                'dataSource': 'YAHOO',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.lookupAssets(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      query: ' VWCE.MI ',
    );

    expect(calls, 1);
    expect(result.items.single.symbol, 'VWCE.MI');
  });

  test('empty search does not issue HTTP requests', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected network request');
      }),
    );

    final result = await api.lookupAssets(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      query: '   ',
    );

    expect(result.items, isEmpty);
  });

  test('accepts the official maximum query length', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.url.queryParameters['query']?.length, 255);
        return http.Response(
          jsonEncode({'items': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await api.lookupAssets(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      query: 'A' * 255,
    );

    expect(result.items, isEmpty);
  });

  test('rejects queries exceeding the official maximum', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected network request');
      }),
    );

    await expectLater(
      api.lookupAssets(serverUrl: serverUrl, jwt: 'jwt-test', query: 'A' * 256),
      throwsFormatException,
    );
  });

  test('rejects invalid search queries before HTTP', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected network request');
      }),
    );

    for (final query in ['VWCE\nMI', 'VWCE\rMI']) {
      await expectLater(
        api.lookupAssets(serverUrl: serverUrl, jwt: 'jwt-test', query: query),
        throwsFormatException,
      );
    }
  });

  test('propagates lookup HTTP errors', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        return http.Response('Server error', 500);
      }),
    );

    await expectLater(
      api.lookupAssets(serverUrl: serverUrl, jwt: 'jwt-test', query: 'VWCE'),
      throwsA(
        isA<PortfolioApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });
}
