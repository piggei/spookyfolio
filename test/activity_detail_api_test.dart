import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  const serverUrl = 'https://ghostfol.io';
  const activityId = '11111111-2222-3333-4444-555555555555';
  const otherId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  Map<String, dynamic> activityJson({String id = activityId}) => {
    'id': id,
    'date': '2026-11-20T12:30:00.000Z',
    'type': 'BUY',
    'currency': 'EUR',
    'quantity': 2,
    'unitPrice': 100.25,
    'fee': 1.5,
    'value': 200.5,
    'assetProfile': {'name': 'Example ETF', 'symbol': 'EXAMPLE'},
    'account': {'name': 'Brokerage'},
  };

  test('fetches an activity by ID', () async {
    var requests = 0;

    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        requests++;

        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/activities/$activityId');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['authorization'], 'Bearer jwt-test');
        expect(request.followRedirects, isFalse);

        return http.Response(
          jsonEncode(activityJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final activity = await api.getActivityById(
      serverUrl: serverUrl,
      jwt: 'jwt-test',
      activityId: activityId,
    );

    expect(requests, 1);
    expect(activity.id, activityId);
    expect(activity.type, 'BUY');
    expect(activity.symbol, 'EXAMPLE');
    expect(activity.accountName, 'Brokerage');
    expect(activity.currency, 'EUR');
    expect(activity.quantity, 2);
    expect(activity.unitPrice, 100.25);
    expect(activity.fee, 1.5);
    expect(activity.value, 200.5);
  });

  test('rejects invalid activity IDs before HTTP', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected network request');
      }),
    );

    for (final id in [
      '',
      'invalid',
      '../accounts',
      '11111111-2222-3333-4444-555555555555/other',
    ]) {
      await expectLater(
        api.getActivityById(
          serverUrl: serverUrl,
          jwt: 'jwt-test',
          activityId: id,
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects a mismatched activity ID', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        return http.Response(
          jsonEncode(activityJson(id: otherId)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.getActivityById(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        activityId: activityId,
      ),
      throwsFormatException,
    );
  });

  test('propagates HTTP 404 for a missing activity', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        return http.Response('Not Found', 404);
      }),
    );

    try {
      await api.getActivityById(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        activityId: activityId,
      );

      fail('Expected PortfolioApiException');
    } on PortfolioApiException catch (error) {
      expect(error.statusCode, 404);
    }
  });

  test('rejects malformed activity JSON', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        return http.Response(
          jsonEncode({'id': activityId, 'date': 'invalid-date', 'type': 'BUY'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.getActivityById(
        serverUrl: serverUrl,
        jwt: 'jwt-test',
        activityId: activityId,
      ),
      throwsFormatException,
    );
  });
}
