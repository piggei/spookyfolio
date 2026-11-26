import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'server_info.dart';

typedef HttpClientFactory = http.Client Function();

class ServerClient {
  ServerClient({HttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final HttpClientFactory _clientFactory;

  static const _timeout = Duration(seconds: 12);
  static const _maxResponseBytes = 1024 * 1024;

  // Cleartext is accepted only for literal private/loopback IPv4 hosts.
  // DNS names are deliberately excluded to avoid DNS rebinding.
  static bool isPrivateLanHttp(Uri uri) {
    if (uri.scheme != 'http') return false;
    final host = uri.host;
    if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
      return false;
    }
    final parts = host.split('.').map(int.parse).toList();
    if (parts.any((part) => part > 255)) return false;
    // Reject ambiguous non-canonical IPv4 spelling.
    if (parts.join('.') != host) return false;
    final a = parts[0], b = parts[1];
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        a == 127;
  }

  static Uri infoUri(String address) {
    final uri = Uri.tryParse(address.trim());

    if (uri == null ||
        (uri.scheme != 'https' && !isPrivateLanHttp(uri)) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Enter a valid HTTPS address or private IPv4 HTTP address without a path',
      );
    }

    return uri.replace(path: '/api/v1/info');
  }

  Future<ServerInfo> inspect(String address) async {
    final uri = infoUri(address);
    final client = _clientFactory();

    try {
      return await _requestInfo(client, uri).timeout(_timeout);
    } finally {
      client.close();
    }
  }

  Future<ServerInfo> _requestInfo(http.Client client, Uri uri) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers[HttpHeaders.acceptHeader] = 'application/json';

    final response = await client.send(request);

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Server returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();

    if (contentType != 'application/json') {
      throw const FormatException('Expected a JSON response from Ghostfolio');
    }

    final contentLength = response.contentLength;

    if (contentLength != null && contentLength > _maxResponseBytes) {
      throw const FormatException('Server information response is too large');
    }

    final bytes = <int>[];

    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw const FormatException('Server information response is too large');
      }

      bytes.addAll(chunk);
    }

    final data = jsonDecode(utf8.decode(bytes));

    return ServerInfo.fromJson(data);
  }
}
