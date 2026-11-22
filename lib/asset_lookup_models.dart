class AssetLookupItem {
  const AssetLookupItem({
    required this.symbol,
    required this.currency,
    this.dataSource,
    this.name,
  });

  final String symbol;
  final String currency;
  final String? dataSource;
  final String? name;

  bool get canFilter => dataSource != null && dataSource!.isNotEmpty;

  factory AssetLookupItem.fromJson(Map<String, dynamic> json) {
    final symbol = json['symbol'];
    final currency = json['currency'];
    final dataSource = json['dataSource'];
    final name = json['name'];

    if (symbol is! String ||
        symbol.trim().isEmpty ||
        currency is! String ||
        currency.trim().isEmpty) {
      throw const FormatException('Invalid asset lookup item');
    }

    if (dataSource != null &&
        (dataSource is! String ||
            !RegExp(r'^[A-Za-z0-9_]+$').hasMatch(dataSource))) {
      throw const FormatException('Invalid asset lookup data source');
    }

    if (name != null && name is! String) {
      throw const FormatException('Invalid asset lookup name');
    }

    return AssetLookupItem(
      symbol: symbol,
      currency: currency,
      dataSource: dataSource as String?,
      name: name as String?,
    );
  }
}

class AssetLookupResults {
  const AssetLookupResults(this.items);

  final List<AssetLookupItem> items;

  factory AssetLookupResults.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];

    if (raw is! List) {
      throw const FormatException('Invalid asset lookup response');
    }

    return AssetLookupResults(
      List.unmodifiable(
        raw.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid asset lookup item');
          }
          return AssetLookupItem.fromJson(item);
        }),
      ),
    );
  }
}
