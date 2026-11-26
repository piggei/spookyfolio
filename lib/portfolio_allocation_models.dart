/// Standard Ghostfolio allocation contracts. Ratios are fractions, not 0–100.
/// Nullable fields preserve missing/redacted data; no monetary values are inferred.
class AllocationEntity {
  const AllocationEntity({
    required this.id,
    this.name,
    this.currency,
    this.balance,
    this.quantity,
    this.valueInBaseCurrency,
    this.valueInPercentage,
  });
  final String id;
  final String? name;
  final String? currency;
  final double? balance;
  final double? quantity;
  final double? valueInBaseCurrency;
  final double? valueInPercentage;

  factory AllocationEntity.fromJson(String id, Map<String, dynamic> json) =>
      AllocationEntity(
        id: id,
        name: allocationString(json, 'name'),
        currency: allocationString(json, 'currency'),
        balance: allocationNumber(json, 'balance'),
        quantity: allocationNumber(json, 'quantity'),
        valueInBaseCurrency: allocationNumber(json, 'valueInBaseCurrency'),
        valueInPercentage: allocationNumber(json, 'valueInPercentage'),
      );
}

class AllocationMarket {
  const AllocationMarket({
    required this.id,
    this.valueInBaseCurrency,
    this.valueInPercentage,
  });
  final String id;
  final double? valueInBaseCurrency;
  final double? valueInPercentage;

  factory AllocationMarket.fromJson(String key, Map<String, dynamic> json) {
    final id = allocationString(json, 'id') ?? key;
    if (id != key) {
      throw const FormatException('Market ID does not match its key');
    }
    return AllocationMarket(
      id: id,
      valueInBaseCurrency: allocationNumber(json, 'valueInBaseCurrency'),
      valueInPercentage: allocationNumber(json, 'valueInPercentage'),
    );
  }
}

class AllocationCountry {
  const AllocationCountry({this.code, this.continent, this.name, this.weight});
  final String? code;
  final String? continent;
  final String? name;
  final double? weight;
  factory AllocationCountry.fromJson(Map<String, dynamic> json) =>
      AllocationCountry(
        code: allocationString(json, 'code'),
        continent: allocationString(json, 'continent'),
        name: allocationString(json, 'name'),
        weight: allocationNumber(json, 'weight'),
      );
}

class AllocationSector {
  const AllocationSector({this.name, this.weight});
  final String? name;
  final double? weight;
  factory AllocationSector.fromJson(Map<String, dynamic> json) =>
      AllocationSector(
        name: allocationString(json, 'name'),
        weight: allocationNumber(json, 'weight'),
      );
}

class AllocationUnderlyingHolding {
  const AllocationUnderlyingHolding({
    this.name,
    this.allocationInPercentage,
    this.valueInBaseCurrency,
  });
  final String? name;
  final double? allocationInPercentage;
  final double? valueInBaseCurrency;
  factory AllocationUnderlyingHolding.fromJson(Map<String, dynamic> json) =>
      AllocationUnderlyingHolding(
        name: allocationString(json, 'name'),
        allocationInPercentage: allocationNumber(
          json,
          'allocationInPercentage',
        ),
        valueInBaseCurrency: allocationNumber(json, 'valueInBaseCurrency'),
      );
}

class PortfolioAllocationAsset {
  const PortfolioAllocationAsset({
    this.name,
    this.currency,
    this.assetClass,
    this.assetSubClass,
    this.assetClassLabel,
    this.assetSubClassLabel,
    this.countries,
    this.sectors,
    this.holdings,
    this.isin,
  });
  final String? name;
  final String? currency;
  final String? assetClass;
  final String? assetSubClass;
  final String? assetClassLabel;
  final String? assetSubClassLabel;
  final String? isin;
  final List<AllocationCountry>? countries;
  final List<AllocationSector>? sectors;
  final List<AllocationUnderlyingHolding>? holdings;
  bool get isCash => assetSubClass == 'CASH';

  factory PortfolioAllocationAsset.fromJson(Map<String, dynamic> json) =>
      PortfolioAllocationAsset(
        name: allocationString(json, 'name'),
        currency: allocationString(json, 'currency'),
        assetClass: allocationString(json, 'assetClass'),
        assetSubClass: allocationString(json, 'assetSubClass'),
        assetClassLabel: allocationString(json, 'assetClassLabel'),
        assetSubClassLabel: allocationString(json, 'assetSubClassLabel'),
        isin: allocationString(json, 'isin'),
        countries: allocationList(
          json,
          'countries',
          AllocationCountry.fromJson,
        ),
        sectors: allocationList(json, 'sectors', AllocationSector.fromJson),
        holdings: allocationList(
          json,
          'holdings',
          AllocationUnderlyingHolding.fromJson,
        ),
      );
}

/// Summary fields used to contextualize allocation; no derived net-worth formula.
class PortfolioAllocationSummary {
  const PortfolioAllocationSummary({
    this.currentNetWorth,
    this.currentValueInBaseCurrency,
    this.filteredValueInBaseCurrency,
    this.filteredValueInPercentage,
    this.totalAssetsInBaseCurrency,
    this.totalCashInBaseCurrency,
    this.totalValueInBaseCurrency,
    this.liabilitiesInBaseCurrency,
    this.excludedAccountsAndActivities,
    this.totalInvestment,
    this.totalInvestmentValueWithCurrencyEffect,
    this.cash,
  });
  final double? currentNetWorth;
  final double? currentValueInBaseCurrency;
  final double? filteredValueInBaseCurrency;
  final double? filteredValueInPercentage;
  final double? totalAssetsInBaseCurrency;
  final double? totalCashInBaseCurrency;
  final double? totalValueInBaseCurrency;
  final double? liabilitiesInBaseCurrency;
  final double? excludedAccountsAndActivities;
  final double? totalInvestment;
  final double? totalInvestmentValueWithCurrencyEffect;
  final double? cash;

  factory PortfolioAllocationSummary.fromJson(Map<String, dynamic> json) =>
      PortfolioAllocationSummary(
        currentNetWorth: allocationNumber(json, 'currentNetWorth'),
        currentValueInBaseCurrency: allocationNumber(
          json,
          'currentValueInBaseCurrency',
        ),
        filteredValueInBaseCurrency: allocationNumber(
          json,
          'filteredValueInBaseCurrency',
        ),
        filteredValueInPercentage: allocationNumber(
          json,
          'filteredValueInPercentage',
        ),
        totalAssetsInBaseCurrency: allocationNumber(
          json,
          'totalAssetsInBaseCurrency',
        ),
        totalCashInBaseCurrency: allocationNumber(
          json,
          'totalCashInBaseCurrency',
        ),
        totalValueInBaseCurrency: allocationNumber(
          json,
          'totalValueInBaseCurrency',
        ),
        liabilitiesInBaseCurrency: allocationNumber(
          json,
          'liabilitiesInBaseCurrency',
        ),
        excludedAccountsAndActivities: allocationNumber(
          json,
          'excludedAccountsAndActivities',
        ),
        totalInvestment: allocationNumber(json, 'totalInvestment'),
        totalInvestmentValueWithCurrencyEffect: allocationNumber(
          json,
          'totalInvestmentValueWithCurrencyEffect',
        ),
        cash: allocationNumber(json, 'cash'),
      );
}

// Shared strict readers also used by the existing REST DTOs.
double? allocationNumber(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite) {
    throw FormatException('Invalid numeric field: $key');
  }
  return raw.toDouble();
}

String? allocationString(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String) throw FormatException('Invalid string field: $key');
  return raw;
}

DateTime? allocationDate(Map<String, dynamic> json, String key) {
  final raw = allocationString(json, key);
  if (raw == null) return null;
  final date = DateTime.tryParse(raw);
  if (date == null) throw FormatException('Invalid date field: $key');
  return date;
}

List<T>? allocationList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! List) throw FormatException('Invalid list: $key');
  return List.unmodifiable(
    raw.map((row) {
      if (row is! Map<String, dynamic>) {
        throw FormatException('Invalid item: $key');
      }
      return parse(row);
    }),
  );
}

Map<String, T>? allocationMap<T>(
  Map<String, dynamic> json,
  String key,
  T Function(String, Map<String, dynamic>) parse,
) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! Map<String, dynamic>) throw FormatException('Invalid map: $key');
  return Map.unmodifiable(
    raw.map((id, row) {
      if (row is! Map<String, dynamic>) {
        throw FormatException('Invalid item: $key');
      }
      return MapEntry(id, parse(id, row));
    }),
  );
}

Map<String, double?>? allocationWeights(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! Map<String, dynamic>) {
    throw FormatException('Invalid weights: $key');
  }
  return Map.unmodifiable({
    for (final id in raw.keys) id: allocationNumber(raw, id),
  });
}
