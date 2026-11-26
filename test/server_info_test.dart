import 'package:flutter_test/flutter_test.dart';
import 'package:spookyfolio/server_client.dart';
import 'package:spookyfolio/server_info.dart';

void main() {
  final validInfo = {
    'baseCurrency': 'USD',
    'currencies': ['USD', 'EUR'],
    'globalPermissions': <String>[],
  };
  test('Recognizes NG', () {
    final info = ServerInfo.fromJson({...validInfo, 'isGhostfolioNg': true});
    expect(info.isGhostfolioNg, isTrue);
  });

  test('Accepts standard upstream without NG field', () {
    final info = ServerInfo.fromJson(validInfo);
    expect(info.isGhostfolioNg, isFalse);
  });

  test('Rejects invalid NG field', () {
    expect(
      () => ServerInfo.fromJson({...validInfo, 'isGhostfolioNg': 'true'}),
      throwsFormatException,
    );
  });

  test('Builds HTTPS API URL', () {
    expect(
      ServerClient.infoUri('https://example.com').toString(),
      'https://example.com/api/v1/info',
    );
  });

  test('Accepts literal private IPv4 and loopback HTTP with ports', () {
    for (final address in [
      'http://192.168.1.14:3333',
      'http://10.0.0.5:3333',
      'http://172.16.0.10:3333',
      'http://172.31.255.254',
      'http://127.0.0.1:3333',
    ]) {
      expect(ServerClient.infoUri(address).path, '/api/v1/info');
      expect(ServerClient.infoUri(address).scheme, 'http');
    }
    expect(
      ServerClient.infoUri('http://192.168.1.14:3333').toString(),
      'http://192.168.1.14:3333/api/v1/info',
    );
  });

  test('Rejects public, ambiguous and hostname HTTP', () {
    for (final address in [
      'http://example.com',
      'http://localhost:3333',
      'http://8.8.8.8:3333',
      'http://192.168.001.14:3333',
      'http://0300.0250.1.14:3333',
      'http://3232235790:3333',
      'http://0xC0A8010E:3333',
      'http://192.168.1.14.:3333',
      'http://169.254.1.1',
      'http://172.32.0.1',
      'http://192.168.1.14:3333/api',
      'http://user:pass@192.168.1.14:3333',
      'http://192.168.1.14:3333?x=1',
      'http://192.168.1.14:3333/#fragment',
    ]) {
      expect(
        () => ServerClient.infoUri(address),
        throwsFormatException,
        reason: address,
      );
    }
  });

  test('Rejects insecure HTTP', () {
    expect(
      () => ServerClient.infoUri('http://example.com'),
      throwsFormatException,
    );
  });

  test('Rejects unexpected URL paths', () {
    expect(
      () => ServerClient.infoUri('https://example.com/admin'),
      throwsFormatException,
    );
  });

  test('Rejects unrelated JSON servers', () {
    expect(() => ServerInfo.fromJson({'status': 'ok'}), throwsFormatException);
  });

  test('Rejects malformed currencies', () {
    expect(
      () => ServerInfo.fromJson({
        ...validInfo,
        'currencies': ['USD', 123],
      }),
      throwsFormatException,
    );
  });
}
