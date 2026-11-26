import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spookyfolio/server_client.dart';

void main() {
  final validInfo = {
    'baseCurrency': 'USD',
    'currencies': ['USD', 'EUR'],
    'globalPermissions': <String>[],
  };

  ServerClient mockClient(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return ServerClient(clientFactory: () => MockClient(handler));
  }

  test('Recognizes a real-format NG HTTP response', () async {
    final client = mockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://example.com/api/v1/info');
      expect(request.followRedirects, isFalse);

      return http.Response(
        jsonEncode({...validInfo, 'isGhostfolioNg': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await client.inspect('https://example.com');

    expect(result.isGhostfolioNg, isTrue);
  });

  test('Inspects private LAN HTTP without redirecting', () async {
    final client = mockClient((request) async {
      expect(request.url.toString(), 'http://192.168.1.14:3333/api/v1/info');
      expect(request.followRedirects, isFalse);
      return http.Response(
        jsonEncode(validInfo),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final result = await client.inspect('http://192.168.1.14:3333');
    expect(result.isGhostfolioNg, isFalse);
  });

  test('Rejects redirects from private LAN HTTP', () async {
    final client = mockClient((request) async {
      expect(request.followRedirects, isFalse);
      return http.Response(
        '',
        302,
        headers: {'location': 'https://example.com'},
      );
    });
    await expectLater(
      client.inspect('http://192.168.1.14:3333'),
      throwsA(isA<HttpException>()),
    );
  });

  test('Recognizes upstream HTTP response', () async {
    final client = mockClient((_) async {
      return http.Response(
        jsonEncode(validInfo),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await client.inspect('https://example.com');

    expect(result.isGhostfolioNg, isFalse);
  });

  test('Rejects an HTTP authentication error', () async {
    final client = mockClient((_) async {
      return http.Response('Unauthorized', 401);
    });

    await expectLater(
      client.inspect('https://example.com'),
      throwsA(isA<HttpException>()),
    );
  });

  test('Rejects an HTTP redirect', () async {
    final client = mockClient((_) async {
      return http.Response(
        '',
        302,
        headers: {'location': 'https://another.example.com'},
      );
    });

    await expectLater(
      client.inspect('https://example.com'),
      throwsA(isA<HttpException>()),
    );
  });

  test('Rejects an HTML response', () async {
    final client = mockClient((_) async {
      return http.Response(
        '<html>Not Ghostfolio</html>',
        200,
        headers: {'content-type': 'text/html'},
      );
    });

    await expectLater(
      client.inspect('https://example.com'),
      throwsFormatException,
    );
  });

  test('Rejects an oversized response', () async {
    final client = mockClient((_) async {
      return http.Response(
        'x' * (1024 * 1024 + 1),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      client.inspect('https://example.com'),
      throwsFormatException,
    );
  });
}
