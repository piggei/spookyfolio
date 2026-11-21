class HoldingPricePoint {
  const HoldingPricePoint({
    required this.date,
    this.marketPrice,
    this.averagePrice,
  });

  final DateTime date;
  final double? marketPrice;
  final double? averagePrice;
}

class HoldingDetailData {
  const HoldingDetailData({
    this.quantity,
    this.averagePrice,
    this.marketPrice,
    this.marketPriceMin,
    this.marketPriceMax,
    this.netPerformance,
    this.netPerformancePercent,
    this.netPerformanceWithCurrencyEffect,
    this.netPerformancePercentWithCurrencyEffect,
    this.investmentInBaseCurrencyWithCurrencyEffect,
    this.feeInBaseCurrency,
    this.dividendInBaseCurrency,
    this.dividendYieldPercentWithCurrencyEffect,
    this.assetCurrency,
    this.assetClass,
    this.assetSubClass,
    this.isin,
    this.dataSource,
    this.dateOfFirstActivity,
    this.activitiesCount,
    this.history = const [],
  });

  final double? quantity;
  final double? averagePrice;
  final double? marketPrice;
  final double? marketPriceMin;
  final double? marketPriceMax;
  final double? netPerformance;
  final double? netPerformancePercent;
  final double? netPerformanceWithCurrencyEffect;
  final double? netPerformancePercentWithCurrencyEffect;
  final double? investmentInBaseCurrencyWithCurrencyEffect;
  final double? feeInBaseCurrency;
  final double? dividendInBaseCurrency;
  final double? dividendYieldPercentWithCurrencyEffect;
  final String? assetCurrency;
  final String? assetClass;
  final String? assetSubClass;
  final String? isin;
  final String? dataSource;
  final DateTime? dateOfFirstActivity;
  final int? activitiesCount;
  final List<HoldingPricePoint> history;

  factory HoldingDetailData.fromJson(Map<String, dynamic> json) {
    double? number(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid holding field: $key');
      }
      return value.toDouble();
    }

    String? string(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Invalid holding field: $key');
      }
      return value;
    }

    final profile = json['assetProfile'];
    if (profile != null && profile is! Map<String, dynamic>) {
      throw const FormatException('Invalid holding profile');
    }
    final asset = profile is Map<String, dynamic>
        ? profile
        : <String, dynamic>{};
    final count = json['activitiesCount'];
    if (count != null && (count is! int || count < 0)) {
      throw const FormatException('Invalid activity count');
    }
    final rawHistory = json['historicalData'];
    if (rawHistory != null && rawHistory is! List) {
      throw const FormatException('Invalid holding history');
    }
    final parsedHistory = <HoldingPricePoint>[];
    if (rawHistory is List) {
      for (final entry in rawHistory) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid holding history point');
        }
        final dateText = string(entry, 'date');
        final date = dateText == null ? null : DateTime.tryParse(dateText);
        if (date == null) {
          throw const FormatException('Invalid holding history date');
        }
        parsedHistory.add(
          HoldingPricePoint(
            date: date,
            marketPrice: number(entry, 'marketPrice'),
            averagePrice: number(entry, 'averagePrice'),
          ),
        );
      }
    }
    parsedHistory.sort((a, b) => a.date.compareTo(b.date));

    final firstDateText = string(json, 'dateOfFirstActivity');
    final firstDate = firstDateText == null
        ? null
        : DateTime.tryParse(firstDateText);
    if (firstDateText != null && firstDate == null) {
      throw const FormatException('Invalid first activity date');
    }

    return HoldingDetailData(
      quantity: number(json, 'quantity'),
      averagePrice: number(json, 'averagePrice'),
      marketPrice: number(json, 'marketPrice'),
      marketPriceMin: number(json, 'marketPriceMin'),
      marketPriceMax: number(json, 'marketPriceMax'),
      netPerformance: number(json, 'netPerformance'),
      netPerformancePercent: number(json, 'netPerformancePercent'),
      netPerformanceWithCurrencyEffect: number(
        json,
        'netPerformanceWithCurrencyEffect',
      ),
      netPerformancePercentWithCurrencyEffect: number(
        json,
        'netPerformancePercentWithCurrencyEffect',
      ),
      investmentInBaseCurrencyWithCurrencyEffect: number(
        json,
        'investmentInBaseCurrencyWithCurrencyEffect',
      ),
      feeInBaseCurrency: number(json, 'feeInBaseCurrency'),
      dividendInBaseCurrency: number(json, 'dividendInBaseCurrency'),
      dividendYieldPercentWithCurrencyEffect: number(
        json,
        'dividendYieldPercentWithCurrencyEffect',
      ),
      assetCurrency: string(asset, 'currency'),
      assetClass: string(asset, 'assetClass'),
      assetSubClass: string(asset, 'assetSubClass'),
      isin: string(asset, 'isin'),
      dataSource: string(asset, 'dataSource'),
      dateOfFirstActivity: firstDate,
      activitiesCount: count as int?,
      history: List.unmodifiable(parsedHistory),
    );
  }
}
