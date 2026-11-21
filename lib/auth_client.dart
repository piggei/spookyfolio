import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'server_client.dart';

class AuthClient {
  AuthClient({HttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final HttpClientFactory _clientFactory;

  static const _timeout = Duration(seconds: 12);

  Future<String> authenticate({
    required String serverUrl,
    required String accessToken,
  }) async {
    if (accessToken.trim().isEmpty) {
      throw const FormatException('Security token is required');
    }

    final infoUri = ServerClient.infoUri(serverUrl);
    final authUri = infoUri.replace(path: '/api/v1/auth/anonymous');
    final client = _clientFactory();

    try {
      return await _authenticate(
        client,
        authUri,
        accessToken,
      ).timeout(_timeout);
    } finally {
      client.close();
    }
  }

  Future<String> _authenticate(
    http.Client client,
    Uri uri,
    String accessToken,
  ) async {
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..headers[HttpHeaders.contentTypeHeader] = 'application/json'
      ..body = jsonEncode({'accessToken': accessToken});

    final response = await client.send(request);

    if (response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.unauthorized) {
      throw const AuthException('Invalid security token');
    }

    if (response.statusCode != HttpStatus.created &&
        response.statusCode != HttpStatus.ok) {
      throw AuthException(
        'Authentication failed (HTTP ${response.statusCode})',
      );
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();

    if (contentType != 'application/json') {
      throw const FormatException('Invalid authentication content type');
    }

    const maxResponseBytes = 65536;

    if (response.contentLength != null &&
        response.contentLength! > maxResponseBytes) {
      throw const FormatException('Authentication response too large');
    }

    final bytes = <int>[];

    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const FormatException('Authentication response too large');
      }
      bytes.addAll(chunk);
    }

    final data = jsonDecode(utf8.decode(bytes));

    if (data is! Map<String, dynamic> ||
        data['authToken'] is! String ||
        (data['authToken'] as String).isEmpty) {
      throw const FormatException('Invalid authentication response');
    }

    return data['authToken'] as String;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
