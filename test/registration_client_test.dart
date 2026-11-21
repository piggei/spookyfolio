import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/registration_client.dart';

void main() {
  test('Registers an anonymous Cloud user', () async {
    final client = RegistrationClient(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://ghostfol.io/api/v1/user');
        expect(request.followRedirects, false);
        expect(jsonDecode(request.body), {'languageCode': 'en'});
        return http.Response(
          jsonEncode({
            'accessToken': 'new-security-token',
            'authToken': 'new-jwt',
            'role': 'USER',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final result = await client.register(serverUrl: 'https://ghostfol.io');
    expect(result.securityToken, 'new-security-token');
    expect(result.jwt, 'new-jwt');
  });

  test('Reports disabled registration', () async {
    final client = RegistrationClient(
      clientFactory: () => MockClient((_) async => http.Response('', 403)),
    );
    await expectLater(
      client.register(serverUrl: 'https://ghostfol.io'),
      throwsA(isA<RegistrationException>()),
    );
  });

  test('Rejects redirects', () async {
    final client = RegistrationClient(
      clientFactory: () => MockClient((_) async => http.Response('', 302)),
    );
    await expectLater(
      client.register(serverUrl: 'https://ghostfol.io'),
      throwsA(isA<RegistrationException>()),
    );
  });

  test('Rejects missing credentials', () async {
    final client = RegistrationClient(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          '{}',
          201,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await expectLater(
      client.register(serverUrl: 'https://ghostfol.io'),
      throwsFormatException,
    );
  });

  test('Rejects oversized responses', () async {
    final client = RegistrationClient(
      clientFactory: () => MockClient(
        (_) async => http.Response(
          'x' * 65537,
          201,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await expectLater(
      client.register(serverUrl: 'https://ghostfol.io'),
      throwsFormatException,
    );
  });
}
