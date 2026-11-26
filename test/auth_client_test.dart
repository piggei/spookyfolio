import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spookyfolio/auth_client.dart';

void main() {
  test('Authenticates using Ghostfolio security token', () async {
    final client = AuthClient(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://ghostfol.io/api/v1/auth/anonymous',
        );
        expect(request.followRedirects, isFalse);
        expect(jsonDecode(request.body), {
          'accessToken': 'test-security-token',
        });

        return http.Response(
          jsonEncode({'authToken': 'test-jwt'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final token = await client.authenticate(
      serverUrl: 'https://ghostfol.io',
      accessToken: 'test-security-token',
    );

    expect(token, 'test-jwt');
  });

  test('Rejects invalid credentials', () async {
    final client = AuthClient(
      clientFactory: () =>
          MockClient((_) async => http.Response('Forbidden', 403)),
    );

    await expectLater(
      client.authenticate(
        serverUrl: 'https://ghostfol.io',
        accessToken: 'invalid',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('Rejects empty security token', () async {
    final client = AuthClient();

    await expectLater(
      client.authenticate(serverUrl: 'https://ghostfol.io', accessToken: ''),
      throwsFormatException,
    );
  });

  test('Rejects malformed authentication response', () async {
    final client = AuthClient(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          '{"unexpected":"value"}',
          201,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      client.authenticate(
        serverUrl: 'https://ghostfol.io',
        accessToken: 'test',
      ),
      throwsFormatException,
    );
  });

  test('Rejects non-JSON authentication response', () async {
    final client = AuthClient(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          '<html>Login</html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );

    await expectLater(
      client.authenticate(
        serverUrl: 'https://ghostfol.io',
        accessToken: 'test',
      ),
      throwsFormatException,
    );
  });

  test('Rejects oversized authentication response', () async {
    final client = AuthClient(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          'x' * 65537,
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      client.authenticate(
        serverUrl: 'https://ghostfol.io',
        accessToken: 'test',
      ),
      throwsFormatException,
    );
  });

  test('Rejects authentication redirects', () async {
    final client = AuthClient(
      clientFactory: () => MockClient((request) async {
        expect(request.followRedirects, isFalse);

        return http.Response(
          '',
          302,
          headers: {'location': 'https://example.com'},
        );
      }),
    );

    await expectLater(
      client.authenticate(
        serverUrl: 'https://ghostfol.io',
        accessToken: 'test',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test(
    'LAN HTTP authentication rejects redirects and public destinations',
    () async {
      var requests = 0;
      final client = AuthClient(
        clientFactory: () => MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'http://192.168.1.14:3333/api/v1/auth/anonymous',
          );
          expect(request.followRedirects, isFalse);
          expect(jsonDecode(request.body), {'accessToken': 'test-token'});
          return http.Response(
            '',
            302,
            headers: {'location': 'https://example.com'},
          );
        }),
      );

      await expectLater(
        client.authenticate(
          serverUrl: 'http://192.168.1.14:3333',
          accessToken: 'test-token',
        ),
        throwsA(isA<AuthException>()),
      );

      await expectLater(
        client.authenticate(
          serverUrl: 'http://8.8.8.8:3333',
          accessToken: 'test-token',
        ),
        throwsFormatException,
      );

      expect(requests, 1);
    },
  );
}
