/// Read-only models for GET /api/v1/activities.
/// Amounts are copied from the server, not reconstructed from quantity/price.
class ActivityBatch {
  const ActivityBatch({required this.activities, required this.count});

  final List<PortfolioActivity> activities;
  final int count;

  factory ActivityBatch.fromJson(Map<String, dynamic> json) {
    final raw = json['activities'];
    final count = json['count'];
    if (raw is! List || count is! int || count < 0) {
      throw const FormatException('Invalid activities response');
    }
    return ActivityBatch(
      activities: List.unmodifiable(
        raw.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid activity item');
          }
          return PortfolioActivity.fromJson(item);
        }),
      ),
      count: count,
    );
  }
}

class PortfolioActivity {
  const PortfolioActivity({
    required this.id,
    required this.date,
    required this.type,
    this.name,
    this.symbol,
    this.accountName,
    this.currency,
    this.quantity,
    this.unitPrice,
    this.fee,
    this.value,
    this.dataSource,
    this.assetCurrency,
    this.isin,
    this.accountId,
    this.comment,
    this.valueInBaseCurrency,
    this.feeInBaseCurrency,
    this.feeInAssetProfileCurrency,
    this.unitPriceInAssetProfileCurrency,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime date;
  final String type;
  final String? name;
  final String? symbol;
  final String? accountName;
  final String? currency;
  final double? quantity;
  final double? unitPrice;
  final double? fee;
  final double? value;
  final String? dataSource;
  final String? assetCurrency;
  final String? isin;
  final String? accountId;
  final String? comment;
  final double? valueInBaseCurrency;
  final double? feeInBaseCurrency;
  final double? feeInAssetProfileCurrency;
  final double? unitPriceInAssetProfileCurrency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PortfolioActivity.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final dateString = json['date'];
    if (id is! String ||
        id.isEmpty ||
        type is! String ||
        type.isEmpty ||
        dateString is! String) {
      throw const FormatException('Invalid activity');
    }
    final date = DateTime.tryParse(dateString);
    if (date == null) throw const FormatException('Invalid activity date');
    final asset = json['assetProfile'];
    final account = json['account'];
    if (asset != null && asset is! Map<String, dynamic>) {
      throw const FormatException('Invalid activity asset profile');
    }
    if (account != null && account is! Map<String, dynamic>) {
      throw const FormatException('Invalid activity account');
    }
    String? optString(dynamic value) =>
        value is String && value.isNotEmpty ? value : null;
    double? optNumber(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid activity numeric field: $key');
      }
      return value.toDouble();
    }

    DateTime? optDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Invalid activity date field: $key');
      }
      final parsed = DateTime.tryParse(value);
      if (parsed == null) {
        throw FormatException('Invalid activity date field: $key');
      }
      return parsed;
    }

    return PortfolioActivity(
      id: id,
      date: date,
      type: type,
      name: optString(asset?['name']),
      symbol: optString(asset?['symbol']),
      accountName: optString(account?['name']),
      currency: optString(json['currency']),
      quantity: optNumber('quantity'),
      unitPrice: optNumber('unitPrice'),
      fee: optNumber('fee'),
      value: optNumber('value'),
      dataSource: optString(asset?['dataSource']),
      assetCurrency: optString(asset?['currency']),
      isin: optString(asset?['isin']),
      accountId: optString(json['accountId']),
      comment: optString(json['comment']),
      valueInBaseCurrency: optNumber('valueInBaseCurrency'),
      feeInBaseCurrency: optNumber('feeInBaseCurrency'),
      feeInAssetProfileCurrency: optNumber('feeInAssetProfileCurrency'),
      unitPriceInAssetProfileCurrency: optNumber(
        'unitPriceInAssetProfileCurrency',
      ),
      createdAt: optDate('createdAt'),
      updatedAt: optDate('updatedAt'),
    );
  }
}
