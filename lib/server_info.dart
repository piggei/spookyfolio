class ServerInfo {
  const ServerInfo({required this.isGhostfolioNg});

  final bool isGhostfolioNg;

  String get edition => isGhostfolioNg ? 'Ghostfolio NG' : 'Ghostfolio';

  factory ServerInfo.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid server information');
    }

    if (value['baseCurrency'] is! String ||
        (value['baseCurrency'] as String).isEmpty ||
        value['currencies'] is! List ||
        !(value['currencies'] as List).every((item) => item is String) ||
        value['globalPermissions'] is! List ||
        !(value['globalPermissions'] as List).every((item) => item is String)) {
      throw const FormatException('Invalid Ghostfolio server information');
    }

    final edition = value['isGhostfolioNg'];

    if (edition != null && edition is! bool) {
      throw const FormatException('Invalid server edition');
    }

    return ServerInfo(isGhostfolioNg: edition == true);
  }
}
