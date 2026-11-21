import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentials {
  const SavedCredentials({
    required this.serverUrl,
    required this.securityToken,
  });

  final String serverUrl;
  final String securityToken;
}

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'spookyfolio.credentials.v1';

  Future<SavedCredentials?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final object = jsonDecode(value);
      if (object is! Map<String, dynamic>) return null;
      final url = object['url'];
      final token = object['token'];
      if (url is! String || token is! String || url.isEmpty || token.isEmpty) {
        return null;
      }
      return SavedCredentials(serverUrl: url, securityToken: token);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(SavedCredentials value) => _storage.write(
    key: _key,
    value: jsonEncode({'url': value.serverUrl, 'token': value.securityToken}),
  );

  Future<void> clear() => _storage.delete(key: _key);
}
