import 'portfolio_client.dart';
import 'portfolio_allocation_models.dart';

const unknownAllocation = 'UNKNOWN';

// Classification provider weights have rounding noise (~2.3e-8 observed).
// Only used to validate sector/continent coverage; never round financial values.
const _classificationCoverageTolerance = 1e-7;

enum AllocationUnit { baseCurrency, fraction }

enum AllocationBasis {
  portfolio,
  nonCashHoldings,
  serverMarkets,
  fundsWithComposition,
}

class AllocationBucket {
  const AllocationBucket({
    required this.id,
    required this.label,
    required this.value,
    this.children = const [],
    this.dataSources = const {},
  });
  final String id;
  final String label;

  /// Money or a fraction according to the containing breakdown's unit.
  /// Null if any contributing amount/weight is unavailable (never a partial sum).
  final double? value;
  final List<AllocationBucket> children;
  final Set<String> dataSources;

  bool get hasUnavailableValues =>
      value == null || children.any((child) => child.hasUnavailableValues);
  bool get hasUnknownContributions =>
      (id == unknownAllocation && (value == null || value != 0)) ||
      children.any((child) => child.hasUnknownContributions);
}

class AllocationBreakdown {
  const AllocationBreakdown({
    required this.unit,
    required this.basis,
    required this.buckets,
    this.isAvailable = true,
    this.hasIncompleteClassifications = false,
  });
  final AllocationUnit unit;
  final AllocationBasis basis;
  final List<AllocationBucket> buckets;

  /// False when the server omitted/redacted this entire contract section.
  final bool isAvailable;

  /// A non-empty weight list does not cover exactly one whole position, or a
  /// weight is unavailable. Checked per position so shortfalls and excesses
  /// cannot cancel each other out across the portfolio.
  final bool hasIncompleteClassifications;
  bool get hasUnavailableValues =>
      !isAvailable || buckets.any((bucket) => bucket.hasUnavailableValues);
  bool get hasUnknownContributions =>
      buckets.any((bucket) => bucket.hasUnknownContributions);
  bool get isComplete =>
      !hasIncompleteClassifications &&
      !hasUnavailableValues &&
      !hasUnknownContributions;

  /// Sum of the returned buckets, NOT a claim of full classification coverage.
  /// Includes explicit UNKNOWN and chart remainder buckets; null if any bucket
  /// is unavailable. Consumers needing a complete breakdown must use isComplete.
  double? get bucketTotal =>
      isAvailable ? _sum(buckets.map((bucket) => bucket.value)) : null;

  /// Do not expose a known partial/overlapping classification sum as a total.
  /// Quantified UNKNOWN buckets can still have a known total, but isComplete
  /// remains false until all contributions are classified and available.
  double? get total => hasIncompleteClassifications ? null : bucketTotal;
}

class EtfHoldingParent {
  const EtfHoldingParent({
    required this.symbol,
    required this.dataSource,
    required this.name,
    required this.value,
    required this.fractionOfHolding,
  });
  final String symbol;
  final String? dataSource;
  final String name;
  final double? value;
  final double? fractionOfHolding;
}

class EtfHoldingAllocation {
  const EtfHoldingAllocation({
    required this.name,
    required this.value,
    required this.allocationInPercentage,
    required this.parents,
  });
  final String name;
  final double? value;

  /// In money mode: share of funds WITH composition, not share of net worth.
  /// In fraction mode: supplied underlying weight times portfolio value fraction.
  final double? allocationInPercentage;
  final List<EtfHoldingParent> parents;
}

class EtfHoldingAnalysis {
  const EtfHoldingAnalysis({
    required this.unit,
    required this.basis,
    required this.holdings,
    required this.coveredFundValue,
    required this.positionsWithoutComposition,
  });
  final AllocationUnit unit;
  final AllocationBasis basis;
  final List<EtfHoldingAllocation> holdings;
  final double? coveredFundValue;
  final List<String> positionsWithoutComposition;
  bool get isExperimental => true;
  bool get isApproximate => true;
}

/// Pure, session-free allocation preparation. No requests, caches or widgets.
/// The caller chooses units explicitly; missing money never falls back to ratios.
class PortfolioAllocations {
  PortfolioAllocations._({
    required this.baseCurrency,
    required this.proportionOfNetWorth,
    required this.byPlatform,
    required this.byCurrency,
    required this.byAssetClass,
    required this.byHolding,
    required this.bySector,
    required this.byContinent,
    required this.byMarket,
    required this.regions,
    required this.byCountry,
    required this.byAccount,
    required this.byEtfProvider,
    required this.byEtfHolding,
    required this.worldMap,
  });

  final String? baseCurrency;

  /// Server summary.filteredValueInPercentage: not recomputed from the holdings.
  final double? proportionOfNetWorth;
  final AllocationBreakdown byPlatform;
  final AllocationBreakdown byCurrency;
  final AllocationBreakdown byAssetClass;
  final AllocationBreakdown byHolding;
  final AllocationBreakdown bySector;
  final AllocationBreakdown byContinent;

  /// Advanced market classification (the upstream By Market chart).
  final AllocationBreakdown byMarket;

  /// Basic server market proportions alongside the weighted world-map countries.
  final AllocationBreakdown regions;
  final AllocationBreakdown byCountry;
  final AllocationBreakdown byAccount;
  final AllocationBreakdown byEtfProvider;
  final EtfHoldingAnalysis byEtfHolding;

  /// The world map uses the weighted country data before chart remainder filling.
  final AllocationBreakdown worldMap;

  factory PortfolioAllocations.fromSnapshot(
    PortfolioSnapshot snapshot, {
    required AllocationUnit unit,
    required String? baseCurrency,
  }) {
    final currencies = <String, _Bucket>{};
    final classes = <String, _Bucket>{};
    final symbols = <String, _Bucket>{};
    final sectors = <String, _Bucket>{};
    final continents = <String, _Bucket>{};
    final countries = <String, _Bucket>{};
    final countryChart = <String, _Bucket>{};
    final providers = <String, _Bucket>{};
    var incompleteCountries = false;
    var incompleteMapCountries = false;
    var incompleteContinents = false;
    var incompleteSectors = false;
    final nonCash = snapshot.holdings.where(
      (holding) => holding.assetProfile?.isCash != true,
    );
    final nonCashFraction = _sum(
      nonCash.map((holding) => holding.valueInPercentage),
    );
    final percentages = unit == AllocationUnit.fraction;

    double? value(PortfolioHolding holding) =>
        percentages ? holding.valueInPercentage : holding.value;
    double? exposure(PortfolioHolding holding, double? weight) {
      final weighted = _product(value(holding), weight);
      return percentages ? _divide(weighted, nonCashFraction) : weighted;
    }

    for (final holding in snapshot.holdings) {
      final asset = holding.assetProfile;
      final amount = percentages ? holding.allocation : holding.value;
      final currency =
          asset?.assetClass == 'COMMODITY' ||
              asset?.assetSubClass == 'CRYPTOCURRENCY'
          ? unknownAllocation
          : asset?.currency;
      _add(currencies, currency, amount);
      final classId = _classificationId(
        asset?.assetClass,
        asset?.assetClassLabel,
      );
      final subClassId = _classificationId(
        asset?.assetSubClass,
        asset?.assetSubClassLabel,
      );
      final group = _add(
        classes,
        classId,
        amount,
        label: asset?.assetClassLabel,
      );
      // Do not create synthetic subclasses when none are supplied.
      if ((asset?.assetSubClass?.isNotEmpty ?? false) ||
          (asset?.assetSubClassLabel?.isNotEmpty ?? false)) {
        _add(
          group.children,
          subClassId,
          amount,
          label: asset?.assetSubClassLabel,
        );
      }
      final provider = asset?.assetSubClass == 'ETF'
          ? asset?.name?.split(' ').first
          : null;
      _add(providers, provider, amount);
      final symbol = _add(
        symbols,
        holding.symbol,
        value(holding),
        label: holding.name,
      );
      if (holding.dataSource != null) symbol.sources.add(holding.dataSource!);

      if (asset?.isCash == true) continue;
      final countryWeights = asset?.countries;
      if (countryWeights == null || countryWeights.isEmpty) {
        _add(countries, unknownAllocation, exposure(holding, 1));
        _add(countryChart, unknownAllocation, exposure(holding, 1));
        _add(continents, unknownAllocation, exposure(holding, 1));
      } else {
        final coverage = _sum(countryWeights.map((country) => country.weight));
        incompleteMapCountries |= _incompleteWeights(
          countryWeights.map((country) => country.weight),
        );
        // The world map retains raw country exposures. The country donut has
        // its own quantified remainder, as do sector and continent charts.
        if (coverage == null ||
            coverage < 0 ||
            coverage > 1 + _classificationCoverageTolerance ||
            countryWeights.any(
              (country) => country.weight != null && country.weight! < 0,
            )) {
          incompleteCountries = true;
        } else if (1 - coverage > _classificationCoverageTolerance) {
          _add(
            countryChart,
            unknownAllocation,
            exposure(holding, 1 - coverage),
          );
        }
        // Continent exposure can include a quantified unclassified remainder.
        if (coverage == null ||
            coverage < 0 ||
            coverage > 1 + _classificationCoverageTolerance ||
            countryWeights.any(
              (country) => country.weight != null && country.weight! < 0,
            )) {
          incompleteContinents = true;
        } else if (1 - coverage > _classificationCoverageTolerance) {
          _add(continents, unknownAllocation, exposure(holding, 1 - coverage));
        }
        for (final country in countryWeights) {
          final weighted = exposure(holding, country.weight);
          _add(
            countries,
            country.code,
            weighted,
            label: country.name ?? country.code,
          );
          _add(
            countryChart,
            country.code,
            weighted,
            label: country.name ?? country.code,
          );
          _add(continents, country.continent, weighted);
        }
      }
      final sectorWeights = asset?.sectors;
      if (sectorWeights == null || sectorWeights.isEmpty) {
        _add(sectors, unknownAllocation, exposure(holding, 1));
      } else {
        final coverage = _sum(sectorWeights.map((sector) => sector.weight));
        if (coverage == null ||
            coverage < 0 ||
            coverage > 1 + _classificationCoverageTolerance ||
            sectorWeights.any(
              (sector) => sector.weight != null && sector.weight! < 0,
            )) {
          incompleteSectors = true;
        } else if (1 - coverage > _classificationCoverageTolerance) {
          _add(sectors, unknownAllocation, exposure(holding, 1 - coverage));
        }
        for (final sector in sectorWeights) {
          _add(sectors, sector.name, exposure(holding, sector.weight));
        }
      }
    }

    AllocationBreakdown breakdown(
      Map<String, _Bucket> groups, {
      AllocationBasis basis = AllocationBasis.portfolio,
      bool remainder = true,
      bool incompleteClassifications = false,
    }) => AllocationBreakdown(
      unit: unit,
      basis: basis,
      buckets: _freeze(groups, fillRemainder: percentages && remainder),
      hasIncompleteClassifications: incompleteClassifications,
    );

    AllocationBreakdown entities(Map<String, AllocationEntity>? source) {
      final groups = <String, _Bucket>{};
      for (final entity in source?.values ?? <AllocationEntity>[]) {
        _add(
          groups,
          entity.id,
          percentages ? entity.valueInPercentage : entity.valueInBaseCurrency,
          label: entity.name,
        );
      }
      return AllocationBreakdown(
        unit: unit,
        basis: AllocationBasis.portfolio,
        isAvailable: source != null,
        buckets: _freeze(groups, fillRemainder: percentages),
      );
    }

    AllocationBreakdown markets(
      Map<String, AllocationMarket>? source, {
      required bool remainder,
    }) {
      final groups = <String, _Bucket>{};
      for (final market in source?.values ?? <AllocationMarket>[]) {
        _add(
          groups,
          market.id,
          percentages ? market.valueInPercentage : market.valueInBaseCurrency,
        );
      }
      return AllocationBreakdown(
        unit: unit,
        basis: AllocationBasis.serverMarkets,
        isAvailable: source != null,
        buckets: _freeze(groups, fillRemainder: percentages && remainder),
      );
    }

    return PortfolioAllocations._(
      baseCurrency: baseCurrency,
      proportionOfNetWorth: snapshot.summary?.filteredValueInPercentage,
      byPlatform: entities(snapshot.platforms),
      byAccount: entities(snapshot.accounts),
      byCurrency: breakdown(currencies),
      byAssetClass: breakdown(classes),
      byHolding: breakdown(symbols),
      byEtfProvider: breakdown(providers),
      bySector: breakdown(
        sectors,
        basis: AllocationBasis.nonCashHoldings,
        incompleteClassifications: incompleteSectors,
      ),
      byContinent: breakdown(
        continents,
        basis: AllocationBasis.nonCashHoldings,
        incompleteClassifications: incompleteContinents,
      ),
      byCountry: breakdown(
        countryChart,
        basis: AllocationBasis.nonCashHoldings,
        incompleteClassifications: incompleteCountries,
      ),
      byMarket: markets(snapshot.marketsAdvanced, remainder: true),
      regions: markets(snapshot.markets, remainder: false),
      byEtfHolding: _etfHoldings(snapshot, unit),
      worldMap: breakdown(
        countries,
        basis: AllocationBasis.nonCashHoldings,
        incompleteClassifications: incompleteMapCountries,
        remainder: false,
      ),
    );
  }
}

class _Bucket {
  _Bucket(this.id, this.label);
  final String id;
  final String label;
  final total = _Total();
  final children = <String, _Bucket>{};
  final sources = <String>{};
}

String _label(String? value) =>
    value == null || value.isEmpty ? unknownAllocation : value;

String _classificationId(String? code, String? label) =>
    code != null && code.isNotEmpty ? code : _label(label);

bool _incompleteWeights(Iterable<double?> weights) {
  final total = _sum(weights);
  // Ignore binary summation noise, not material classification shortfalls.
  return total == null || (total - 1).abs() > 1e-12;
}

_Bucket _add(
  Map<String, _Bucket> groups,
  String? rawKey,
  double? value, {
  String? label,
}) {
  // Keep source identifiers exact. Upstream's chart-only primary-label case
  // folding is not an identity rule for accounts, markets or secondary keys.
  final key = _label(rawKey);
  final bucket = groups.putIfAbsent(
    key,
    () => _Bucket(key, label == null || label.isEmpty ? key : label),
  );
  bucket.total.add(value);
  return bucket;
}

List<AllocationBucket> _freeze(
  Map<String, _Bucket> groups, {
  bool fillRemainder = false,
}) {
  final result = groups.values
      .map(
        (bucket) => AllocationBucket(
          id: bucket.id,
          label: bucket.label,
          value: bucket.total.value,
          children: _freeze(bucket.children),
          dataSources: Set.unmodifiable(bucket.sources),
        ),
      )
      .toList();
  final sum = _sum(result.map((bucket) => bucket.value));
  // Upstream proportion charts add a material shortfall to UNKNOWN; they never
  // rescale overweight data. Do not fabricate 100% for an empty response.
  if (fillRemainder && result.isNotEmpty && sum != null && 1 - sum > 0.0001) {
    final index = result.indexWhere((bucket) => bucket.id == unknownAllocation);
    if (index < 0) {
      result.add(
        AllocationBucket(
          id: unknownAllocation,
          label: unknownAllocation,
          value: 1 - sum,
        ),
      );
    } else {
      final old = result[index];
      result[index] = AllocationBucket(
        id: old.id,
        label: old.label,
        value: old.value! + 1 - sum,
        children: old.children,
        dataSources: old.dataSources,
      );
    }
  }
  result.sort((a, b) => _descending(a.value, b.value));
  return List.unmodifiable(result);
}

int _descending(double? a, double? b) =>
    a == null ? (b == null ? 0 : 1) : (b == null ? -1 : b.compareTo(a));
double? _product(double? a, double? b) =>
    a == null || b == null ? null : _finite(a * b);
double? _divide(double? value, double? denominator) =>
    value == null || denominator == null
    ? null
    : (denominator == 0
          ? (value == 0 ? 0 : null)
          : _finite(value / denominator));
double _finite(double value) {
  if (!value.isFinite) {
    throw const FormatException('Non-finite allocation result');
  }
  return value;
}

double? _sum(Iterable<double?> values) {
  final total = _Total();
  for (final value in values) {
    total.add(value);
  }
  return total.value;
}

/// Compensated summation retains small exposures without rounding for display.
class _Total {
  double _sum = 0;
  double _correction = 0;
  bool _complete = true;
  void add(double? value) {
    if (value == null) {
      _complete = false;
      return;
    }
    if (!value.isFinite) {
      throw const FormatException('Non-finite allocation value');
    }
    final next = _sum + value;
    _correction += _sum.abs() >= value.abs()
        ? (_sum - next) + value
        : (value - next) + _sum;
    _sum = next;
  }

  double? get value => _complete ? _finite(_sum + _correction) : null;
}

EtfHoldingAnalysis _etfHoldings(
  PortfolioSnapshot snapshot,
  AllocationUnit unit,
) {
  final fractions = unit == AllocationUnit.fraction;
  final groups = <String, _EtfBucket>{};
  final funds = _Total();
  final missing = <String>[];
  for (final position in snapshot.holdings) {
    final asset = position.assetProfile;
    if (asset?.isCash == true) continue;
    final composition = asset?.holdings;
    if (composition == null || composition.isEmpty) {
      if (asset?.assetSubClass == 'ETF' ||
          asset?.assetSubClass == 'MUTUALFUND') {
        missing.add(
          '${position.dataSource ?? unknownAllocation}:${position.symbol}',
        );
      }
      continue;
    }
    funds.add(fractions ? position.allocation : position.value);
    for (final underlying in composition) {
      final name = _label(underlying.name);
      final key = name.trim().toLowerCase();
      final value = fractions
          ? _product(
              underlying.allocationInPercentage,
              position.valueInPercentage,
            )
          : underlying.valueInBaseCurrency;
      final group = groups.putIfAbsent(key, () => _EtfBucket(name));
      group.total.add(value);
      group.parents.add((position: position, value: value));
    }
  }
  final holdings =
      groups.values.map((group) {
        final value = group.total.value;
        final parents =
            group.parents
                .map(
                  (parent) => EtfHoldingParent(
                    symbol: parent.position.symbol,
                    dataSource: parent.position.dataSource,
                    name: parent.position.name,
                    value: parent.value,
                    fractionOfHolding: _divide(parent.value, value),
                  ),
                )
                .toList()
              ..sort(
                (a, b) => _descending(a.fractionOfHolding, b.fractionOfHolding),
              );
        return EtfHoldingAllocation(
          name: group.name,
          value: value,
          allocationInPercentage: fractions
              ? value
              : _divide(value, funds.value),
          parents: List.unmodifiable(parents),
        );
      }).toList()..sort(
        (a, b) =>
            _descending(a.allocationInPercentage, b.allocationInPercentage),
      );
  return EtfHoldingAnalysis(
    unit: unit,
    basis: fractions
        ? AllocationBasis.portfolio
        : AllocationBasis.fundsWithComposition,
    coveredFundValue: funds.value,
    positionsWithoutComposition: List.unmodifiable(missing),
    holdings: List.unmodifiable(holdings.take(50)),
  );
}

class _EtfBucket {
  _EtfBucket(this.name);
  final String name;
  final total = _Total();
  final parents = <({PortfolioHolding position, double? value})>[];
}
