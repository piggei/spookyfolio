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
