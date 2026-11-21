import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'server_client.dart';

class RegistrationResult {
  const RegistrationResult({required this.securityToken, required this.jwt});

  final String securityToken;
  final String jwt;
}

class RegistrationException implements Exception {
  const RegistrationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RegistrationClient {
  RegistrationClient({HttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final HttpClientFactory _clientFactory;

  Future<RegistrationResult> register({required String serverUrl}) async {
    final baseUri = ServerClient.infoUri(serverUrl);
    final uri = baseUri.replace(path: '/api/v1/user');
    final client = _clientFactory();
    try {
      return await _register(client, uri).timeout(const Duration(seconds: 12));
    } finally {
      client.close();
    }
  }

  Future<RegistrationResult> _register(http.Client client, Uri uri) async {
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
      ..body = jsonEncode({'languageCode': 'en'});

    final response = await client.send(request);
    if (response.statusCode == HttpStatus.forbidden) {
      throw const RegistrationException(
        'Account registration is not available on this server.',
      );
    }
    if (response.statusCode != HttpStatus.created) {
      throw RegistrationException(
        'Account registration failed (HTTP ${response.statusCode}).',
      );
    }
    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType != 'application/json') {
      throw const FormatException('Invalid registration content type');
    }
    const maxResponseBytes = 65536;
    if (response.contentLength != null &&
        response.contentLength! > maxResponseBytes) {
      throw const FormatException('Registration response too large');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const FormatException('Registration response too large');
      }
      bytes.addAll(chunk);
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> ||
        data['accessToken'] is! String ||
        (data['accessToken'] as String).isEmpty ||
        data['authToken'] is! String ||
        (data['authToken'] as String).isEmpty) {
      throw const FormatException('Invalid registration response');
    }
    return RegistrationResult(
      securityToken: data['accessToken'] as String,
      jwt: data['authToken'] as String,
    );
  }
}
