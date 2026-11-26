import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test(
    'fetches real Ghostfolio endpoint shapes with Bearer authentication',
    () async {
      final requested = <String>[];
      final client = PortfolioClient(
        clientFactory: () => MockClient((request) async {
          requested.add(request.url.path);
          expect(request.headers['authorization'], 'Bearer jwt-test');
          expect(request.followRedirects, false);
          final data = switch (request.url.path) {
            '/api/v1/user' => {
              'id': 'u1',
              'settings': {'baseCurrency': 'EUR'},
            },
            '/api/v1/portfolio/details' => {
              'holdings': [
                {
                  'assetProfile': {'symbol': 'ABC', 'name': 'Asset ABC'},
                  'allocationInPercentage': 0.4,
                  'valueInBaseCurrency': 20.0,
                },
              ],
              'summary': {
                'currentNetWorth': 50.0,
                'netPerformance': -2.0,
                'netPerformancePercentage': -0.04,
              },
            },
            '/api/v2/portfolio/performance' => {
              'chart': [
                {'date': '2026-01-01', 'value': 40},
                {'date': '2026-02-01', 'value': 50},
              ],
            },
            _ => throw StateError('Unexpected path: ${request.url.path}'),
          };
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final profile = await client.getProfile(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt-test',
      );
      final details = await client.getDetails(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt-test',
      );
      final history = await client.getHistory(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt-test',
      );
      expect(profile.baseCurrency, 'EUR');
      expect(details.netWorth, 50);
      expect(details.netPerformancePercentage, -0.04);
      expect(details.holdings.single.symbol, 'ABC');
      expect(history.points.length, 2);
      expect(requested, [
        '/api/v1/user',
        '/api/v1/portfolio/details',
        '/api/v2/portfolio/performance',
      ]);
    },
  );

  test('does not reinterpret redacted values as zero', () {
    final details = PortfolioSnapshot.fromJson({
      'holdings': [],
      'summary': {'currentNetWorth': null},
    });
    expect(details.netWorth, isNull);
    expect(details.netPerformance, isNull);
  });

  test('rejects an expired session and does not follow redirects', () async {
    final client = PortfolioClient(
      clientFactory: () => MockClient((req) async => http.Response('', 401)),
    );
    await expectLater(
      client.getProfile(serverUrl: 'https://ghostfol.io', jwt: 'jwt'),
      throwsA(isA<PortfolioApiException>()),
    );
  });

  test('rejects an oversized API response', () async {
    final client = PortfolioClient(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          'x' * (8 * 1024 * 1024 + 1),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await expectLater(
      client.getDetails(serverUrl: 'https://ghostfol.io', jwt: 'jwt'),
      throwsFormatException,
    );
  });

  test('recognizes chart values without inventing missing history', () {
    final history = PortfolioHistory.fromJson({
      'chart': [
        {'date': '2026-03-01', 'value': null},
        {'date': '2026-03-02', 'value': 123.5},
      ],
    });
    expect(history.points.first.value, isNull);
    expect(history.points.last.value, 123.5);
  });

  test(
    'LAN HTTP portfolio requests keep JWT on the validated origin',
    () async {
      var requests = 0;
      final client = PortfolioClient(
        clientFactory: () => MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'http://192.168.1.14:3333/api/v1/user',
          );
          expect(request.headers['authorization'], 'Bearer jwt-test');
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://example.com'},
          );
        }),
      );

      await expectLater(
        client.getProfile(
          serverUrl: 'http://192.168.1.14:3333',
          jwt: 'jwt-test',
        ),
        throwsA(isA<PortfolioApiException>()),
      );

      await expectLater(
        client.getProfile(serverUrl: 'http://8.8.8.8:3333', jwt: 'jwt-test'),
        throwsFormatException,
      );

      expect(requests, 1);
    },
  );
}
