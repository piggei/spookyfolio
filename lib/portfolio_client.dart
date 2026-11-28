import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'server_client.dart';
import 'holding_detail_data.dart';
import 'asset_lookup_models.dart';
import 'activity_models.dart';
import 'portfolio_allocation_models.dart';

class PortfolioApiException implements Exception {
  const PortfolioApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class GhostfolioProfile {
  const GhostfolioProfile({
    required this.id,
    this.baseCurrency,
    this.locale,
    this.performanceCalculationType,
  });
  final String id;
  final String? baseCurrency;
  final String? locale;
  final String? performanceCalculationType;

  factory GhostfolioProfile.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'];
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        settings is! Map<String, dynamic>) {
      throw const FormatException('Invalid user profile');
    }
    return GhostfolioProfile(
      id: json['id'] as String,
      baseCurrency: settings['baseCurrency'] is String
          ? settings['baseCurrency'] as String
          : null,
      locale: settings['locale'] is String
          ? settings['locale'] as String
          : null,
      performanceCalculationType:
          settings['performanceCalculationType'] is String
          ? settings['performanceCalculationType'] as String
          : null,
    );
  }
}

class PortfolioHolding {
  const PortfolioHolding({
    required this.symbol,
    required this.name,
    this.dataSource,
    this.allocation,
    this.value,
    this.netPerformance,
    this.netPerformancePercent,
    this.valueInPercentage,
    this.assetProfile,
    this.markets,
    this.marketsAdvanced,
  });
  final String symbol;
  final String name;
  final String? dataSource;
  final double? allocation;
  final double? value;
  final double? netPerformance;
  final double? netPerformancePercent;
  final double? valueInPercentage;
  final PortfolioAllocationAsset? assetProfile;
  final Map<String, double?>? markets;
  final Map<String, double?>? marketsAdvanced;

  factory PortfolioHolding.fromJson(Map<String, dynamic> json) {
    final asset = json['assetProfile'];
    if (asset is! Map<String, dynamic>) {
      throw const FormatException('Invalid portfolio holding');
    }
    final symbol = asset['symbol'];
    final name = asset['name'];
    if (symbol is! String || (name != null && name is! String)) {
      throw const FormatException('Invalid portfolio holding');
    }
    return PortfolioHolding(
      symbol: symbol,
      name: name as String? ?? symbol,
      dataSource: asset['dataSource'] is String
          ? asset['dataSource'] as String
          : null,
      allocation: _optionalNumber(json, 'allocationInPercentage'),
      value: _optionalNumber(json, 'valueInBaseCurrency'),
      netPerformance: _optionalNumber(json, 'netPerformance'),
      netPerformancePercent: _optionalNumber(json, 'netPerformancePercent'),
      valueInPercentage: _optionalNumber(json, 'valueInPercentage'),
      assetProfile: PortfolioAllocationAsset.fromJson(asset),
      markets: allocationWeights(json, 'markets'),
      marketsAdvanced: allocationWeights(json, 'marketsAdvanced'),
    );
  }
}

class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.holdings,
    this.netWorth,
    this.investedValue,
    this.netPerformance,
    this.netPerformancePercentage,
    this.cash,
    this.hasError = false,
    this.createdAt,
    this.accounts,
    this.platforms,
    this.markets,
    this.marketsAdvanced,
    this.summary,
  });
  final List<PortfolioHolding> holdings;
  final double? netWorth;
  final double? investedValue;
  final double? netPerformance;
  final double? netPerformancePercentage;
  final double? cash;
  final bool hasError;
  final DateTime? createdAt;
  final Map<String, AllocationEntity>? accounts;
  final Map<String, AllocationEntity>? platforms;
  final Map<String, AllocationMarket>? markets;
  final Map<String, AllocationMarket>? marketsAdvanced;
  final PortfolioAllocationSummary? summary;

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) {
    final holdings = json['holdings'];
    if (holdings is! List) {
      throw const FormatException('Invalid portfolio details');
    }
    final summary = json['summary'];
    if (summary != null && summary is! Map<String, dynamic>) {
      throw const FormatException('Invalid portfolio summary');
    }
    final data = summary is Map<String, dynamic>
        ? summary
        : <String, dynamic>{};
    return PortfolioSnapshot(
      holdings: List.unmodifiable(
        holdings.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid portfolio holding item');
          }
          return PortfolioHolding.fromJson(item);
        }),
      ),
      netWorth: _optionalNumber(data, 'currentNetWorth'),
      investedValue: _optionalNumber(data, 'totalInvestment'),
      netPerformance: _optionalNumber(data, 'netPerformance'),
      netPerformancePercentage: _optionalNumber(
        data,
        'netPerformancePercentage',
      ),
      cash: _optionalNumber(data, 'cash'),
      hasError: json['hasError'] == true,
      createdAt: allocationDate(json, 'createdAt'),
      accounts: allocationMap(json, 'accounts', AllocationEntity.fromJson),
      platforms: allocationMap(json, 'platforms', AllocationEntity.fromJson),
      markets: allocationMap(json, 'markets', AllocationMarket.fromJson),
      marketsAdvanced: allocationMap(
        json,
        'marketsAdvanced',
        AllocationMarket.fromJson,
      ),
      summary: summary is Map<String, dynamic>
          ? PortfolioAllocationSummary.fromJson(summary)
          : null,
    );
  }
}

class PortfolioPoint {
  const PortfolioPoint({
    required this.date,
    this.value,
    this.returnWithCurrencyEffect,
    this.totalInvestmentValueWithCurrencyEffect,
    this.valueWithCurrencyEffect,
    this.valueInPercentage,
  });
  final DateTime date;
  final double? value;
  // Ratio reported by Ghostfolio; 0.05 means 5%.
  final double? returnWithCurrencyEffect;
  // Explicit monetary fields used by upstream Portfolio Evolution. Legacy value
  // and normalized valueInPercentage must never stand in for these fields.
  final double? totalInvestmentValueWithCurrencyEffect;
  final double? valueWithCurrencyEffect;
  final double? valueInPercentage;
}

class PortfolioHistory {
  const PortfolioHistory(
    this.points, {
    this.portfolioValue,
    this.changeWithCurrencyEffect,
    this.returnPercentageWithCurrencyEffect,
    this.totalInvestmentValueWithCurrencyEffect,
    this.dateOfFirstActivity,
    this.hasErrors = false,
  });
  final List<PortfolioPoint> points;
  final double? portfolioValue;
  final double? changeWithCurrencyEffect;
  final double? returnPercentageWithCurrencyEffect;
  final double? totalInvestmentValueWithCurrencyEffect;
  final DateTime? dateOfFirstActivity;
  final bool hasErrors;

  factory PortfolioHistory.fromJson(Map<String, dynamic> json) {
    final chart = json['chart'];
    final performance = json['performance'];
    if (performance != null && performance is! Map<String, dynamic>) {
      throw const FormatException('Invalid portfolio performance');
    }
    if (chart != null && chart is! List) {
      throw const FormatException('Invalid portfolio chart');
    }
    final metrics = performance is Map<String, dynamic>
        ? performance
        : <String, dynamic>{};
    return PortfolioHistory(
      List.unmodifiable(
        (chart ?? <dynamic>[]).map((item) {
          if (item is! Map<String, dynamic> || item['date'] is! String) {
            throw const FormatException('Invalid chart point');
          }
          final date = DateTime.tryParse(item['date'] as String);
          if (date == null) throw const FormatException('Invalid chart date');
          return PortfolioPoint(
            date: date,
            value: _optionalNumber(item, 'value'),
            totalInvestmentValueWithCurrencyEffect: _optionalNumber(
              item,
              'totalInvestmentValueWithCurrencyEffect',
            ),
            valueWithCurrencyEffect: _optionalNumber(
              item,
              'valueWithCurrencyEffect',
            ),
            valueInPercentage: _optionalNumber(item, 'valueInPercentage'),
            returnWithCurrencyEffect: _optionalNumber(
              item,
              'netPerformanceInPercentageWithCurrencyEffect',
            ),
          );
        }),
      ),
      portfolioValue: _optionalNumber(metrics, 'currentValueInBaseCurrency'),
      totalInvestmentValueWithCurrencyEffect: _optionalNumber(
        metrics,
        'totalInvestmentValueWithCurrencyEffect',
      ),
      dateOfFirstActivity: allocationDate(json, 'dateOfFirstActivity'),
      hasErrors: json['hasErrors'] == true,
      changeWithCurrencyEffect: _optionalNumber(
        metrics,
        'netPerformanceWithCurrencyEffect',
      ),
      returnPercentageWithCurrencyEffect: _optionalNumber(
        metrics,
        'netPerformancePercentageWithCurrencyEffect',
      ),
    );
  }
}

double? _optionalNumber(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw FormatException('Invalid numeric field: $key');
  }
  return value.toDouble();
}

class PortfolioAccount {
  const PortfolioAccount({
    required this.id,
    required this.name,
    required this.currency,
    this.balance,
    this.value,
    this.platformName,
    this.allocation,
    this.activitiesCount,
    this.dividends,
    this.interest,
  });

  final String id;
  final String name;
  final String currency;
  final double? balance;
  final double? value;
  final String? platformName;
  final double? allocation;
  final int? activitiesCount;
  final double? dividends;
  final double? interest;

  factory PortfolioAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final currency = json['currency'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        currency is! String ||
        currency.isEmpty) {
      throw const FormatException('Invalid account');
    }
    final platform = json['platform'];
    return PortfolioAccount(
      id: id,
      name: name,
      currency: currency,
      balance: _optionalNumber(json, 'balance'),
      value: _optionalNumber(json, 'valueInBaseCurrency'),
      allocation: _optionalNumber(json, 'allocationInPercentage'),
      dividends: _optionalNumber(json, 'dividendInBaseCurrency'),
      interest: _optionalNumber(json, 'interestInBaseCurrency'),
      activitiesCount: _accountCount(json['activitiesCount']),
      platformName:
          platform is Map<String, dynamic> && platform['name'] is String
          ? platform['name'] as String
          : null,
    );
  }
}

int? _accountCount(Object? raw) {
  if (raw == null) return null;
  if (raw is! int || raw < 0) {
    throw const FormatException('Invalid account activity count');
  }
  return raw;
}

class PortfolioAccountBalance {
  const PortfolioAccountBalance({
    required this.id,
    required this.accountId,
    required this.date,
    this.value,
    this.valueInBaseCurrency,
    this.comment,
  });

  final String id;
  final String accountId;
  final DateTime date;
  final double? value;
  final double? valueInBaseCurrency;
  final String? comment;

  factory PortfolioAccountBalance.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final accountId = json['accountId'];
    final rawDate = json['date'];

    if (id is! String ||
        id.isEmpty ||
        accountId is! String ||
        accountId.isEmpty ||
        rawDate is! String) {
      throw const FormatException('Invalid account balance');
    }

    final date = DateTime.tryParse(rawDate);

    if (date == null) {
      throw const FormatException('Invalid account balance date');
    }

    final comment = json['comment'];

    if (comment != null && comment is! String) {
      throw const FormatException('Invalid account balance comment');
    }

    return PortfolioAccountBalance(
      id: id,
      accountId: accountId,
      date: date,
      value: _optionalNumber(json, 'value'),
      valueInBaseCurrency: _optionalNumber(json, 'valueInBaseCurrency'),
      comment: comment as String?,
    );
  }
}

class PortfolioAccountBalances {
  const PortfolioAccountBalances(this.balances);

  final List<PortfolioAccountBalance> balances;

  factory PortfolioAccountBalances.fromJson(Map<String, dynamic> json) {
    final rows = json['balances'];

    if (rows is! List) {
      throw const FormatException('Invalid account balances response');
    }

    return PortfolioAccountBalances(
      List.unmodifiable(
        rows.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid account balance item');
          }
          return PortfolioAccountBalance.fromJson(item);
        }),
      ),
    );
  }
}

class PortfolioAccountsCatalog {
  const PortfolioAccountsCatalog(this.accounts);
  final List<PortfolioAccount> accounts;

  factory PortfolioAccountsCatalog.fromJson(Map<String, dynamic> json) {
    final rows = json['accounts'];
    if (rows is! List) throw const FormatException('Invalid accounts response');
    final accounts = <PortfolioAccount>[];
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid account item');
      }
      final item = PortfolioAccount.fromJson(row);
      if (!ids.add(item.id)) {
        throw const FormatException('Duplicate account ID');
      }
      accounts.add(item);
    }
    return PortfolioAccountsCatalog(List.unmodifiable(accounts));
  }
}

class PortfolioClient {
  PortfolioClient({HttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final HttpClientFactory _clientFactory;
  static const _timeout = Duration(seconds: 20);
  static const _maxResponseBytes = 8 * 1024 * 1024;

  Future<GhostfolioProfile> getProfile({
    required String serverUrl,
    required String jwt,
  }) async {
    final json = await _get(serverUrl, jwt, '/api/v1/user');
    return GhostfolioProfile.fromJson(json);
  }

  Future<PortfolioAccount> getAccountById({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async => PortfolioAccount.fromJson(
    await _get(serverUrl, jwt, '/api/v1/accounts/${_accountId(accountId)}'),
  );

  Future<PortfolioAccountBalances> getAccountBalances({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async {
    final validatedId = _accountId(accountId);

    final result = PortfolioAccountBalances.fromJson(
      await _get(serverUrl, jwt, '/api/v1/accounts/$validatedId/balances'),
    );

    for (final balance in result.balances) {
      if (balance.accountId != validatedId) {
        throw const FormatException(
          'Account balance belongs to a different account',
        );
      }
    }

    return result;
  }

  Future<PortfolioAccountsCatalog> getAccountsCatalog({
    required String serverUrl,
    required String jwt,
  }) async => PortfolioAccountsCatalog.fromJson(
    await _get(serverUrl, jwt, '/api/v1/accounts'),
  );

  Future<PortfolioSnapshot> getDetailsForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
  }) async => PortfolioSnapshot.fromJson(
    await _get(
      serverUrl,
      jwt,
      '/api/v1/portfolio/details',
      queryParameters: {'accounts': _accountId(accountId)},
    ),
  );

  Future<PortfolioHistory> getHistoryForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    String? range,
  }) async {
    const allowed = {'1d', 'wtd', 'mtd', 'ytd', '1y', '5y', 'max'};
    if (range != null && !allowed.contains(range)) {
      throw const FormatException('Unsupported history range');
    }
    return PortfolioHistory.fromJson(
      await _get(
        serverUrl,
        jwt,
        '/api/v2/portfolio/performance',
        range: range,
        queryParameters: {'accounts': _accountId(accountId)},
      ),
    );
  }

  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    if (skip < 0 || take < 1 || take > 100) {
      throw const FormatException('Invalid activity pagination');
    }
    return ActivityBatch.fromJson(
      await _get(
        serverUrl,
        jwt,
        '/api/v1/activities',
        queryParameters: {
          'accounts': _accountId(accountId),
          'skip': '$skip',
          'take': '$take',
          'sortColumn': 'date',
          'sortDirection': 'desc',
        },
      ),
    );
  }

  static String _accountId(String value) {
    final valid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!valid.hasMatch(value)) {
      throw const FormatException('Invalid account ID');
    }
    return value;
  }

  Future<PortfolioSnapshot> getDetails({
    required String serverUrl,
    required String jwt,
  }) async {
    final json = await _get(serverUrl, jwt, '/api/v1/portfolio/details');
    return PortfolioSnapshot.fromJson(json);
  }

  /// Opt-in allocation contract; existing detail calls and subclasses stay unchanged.
  /// No cache: the caller owns the account/session lifetime and shared snapshot.
  Future<PortfolioSnapshot> getAllocationDetails({
    required String serverUrl,
    required String jwt,
    String? accountId,
    bool withMarkets = true,
  }) async => PortfolioSnapshot.fromJson(
    await _get(
      serverUrl,
      jwt,
      '/api/v1/portfolio/details',
      queryParameters: {
        'withMarkets': '$withMarkets',
        if (accountId != null) 'accounts': _accountId(accountId),
      },
    ),
  );

  Future<PortfolioHistory> getHistory({
    required String serverUrl,
    required String jwt,
    String? range,
  }) async {
    const allowed = {'1d', 'wtd', 'mtd', 'ytd', '1y', '5y', 'max'};
    if (range != null && !allowed.contains(range)) {
      throw const FormatException('Unsupported history range');
    }
    final json = await _get(
      serverUrl,
      jwt,
      '/api/v2/portfolio/performance',
      range: range,
    );
    return PortfolioHistory.fromJson(json);
  }

  Future<AssetLookupResults> lookupAssets({
    required String serverUrl,
    required String jwt,
    required String query,
  }) async {
    final search = query.trim();

    if (search.isEmpty) {
      return const AssetLookupResults([]);
    }

    if (search.length > 255 || search.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid asset search query');
    }

    return AssetLookupResults.fromJson(
      await _get(
        serverUrl,
        jwt,
        '/api/v1/symbols/lookup',
        queryParameters: {'query': search},
      ),
    );
  }

  Future<ActivityBatch> getFilteredActivities({
    required String serverUrl,
    required String jwt,
    String? accountId,
    String? dataSource,
    String? symbol,
    int skip = 0,
    int take = 40,
  }) async {
    if (skip < 0 || take < 1 || take > 100) {
      throw const FormatException('Invalid activity pagination');
    }

    if ((dataSource == null) != (symbol == null)) {
      throw const FormatException(
        'Asset filtering requires dataSource and symbol',
      );
    }

    if (dataSource != null &&
        (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(dataSource) ||
            symbol!.trim().isEmpty ||
            symbol.contains(RegExp(r'[\r\n]')))) {
      throw const FormatException('Invalid activity asset filter');
    }

    final query = <String, String>{
      'skip': '$skip',
      'take': '$take',
      'sortColumn': 'date',
      'sortDirection': 'desc',
    };

    if (accountId != null) {
      query['accounts'] = _accountId(accountId);
    }

    if (dataSource != null) {
      query['dataSource'] = dataSource;
      query['symbol'] = symbol!;
    }

    return ActivityBatch.fromJson(
      await _get(serverUrl, jwt, '/api/v1/activities', queryParameters: query),
    );
  }

  Future<PortfolioActivity> getActivityById({
    required String serverUrl,
    required String jwt,
    required String activityId,
  }) async {
    final validId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!validId.hasMatch(activityId)) {
      throw const FormatException('Invalid activity ID');
    }

    final activity = PortfolioActivity.fromJson(
      await _get(serverUrl, jwt, '/api/v1/activities/$activityId'),
    );

    if (activity.id != activityId) {
      throw const FormatException('Activity response ID mismatch');
    }

    return activity;
  }

  Future<ActivityBatch> getActivities({
    required String serverUrl,
    required String jwt,
    int skip = 0,
    int take = 40,
  }) async {
    if (skip < 0 || take < 1 || take > 100) {
      throw const FormatException('Invalid activity pagination');
    }
    final result = await _get(
      serverUrl,
      jwt,
      '/api/v1/activities',
      queryParameters: {
        'skip': '$skip',
        'take': '$take',
        'sortColumn': 'date',
        'sortDirection': 'desc',
      },
    );
    return ActivityBatch.fromJson(result);
  }

  Future<HoldingDetailData> getHoldingDetail({
    required String serverUrl,
    required String jwt,
    required String dataSource,
    required String symbol,
  }) async {
    // Explicit path-segment validation prevents accidental extra URL segments.
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(dataSource) ||
        symbol.isEmpty ||
        symbol.contains(RegExp(r'[/\\?#\r\n]'))) {
      throw FormatException(
        'Invalid holding identifier: source="$dataSource", symbol="$symbol"',
      );
    }
    final json = await _get(
      serverUrl,
      jwt,
      '/api/v1/portfolio/holding/$dataSource/$symbol',
    );
    return HoldingDetailData.fromJson(json);
  }

  Future<ActivityBatch> getHoldingActivities({
    required String serverUrl,
    required String jwt,
    required String dataSource,
    required String symbol,
    int skip = 0,
    int take = 20,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(dataSource) ||
        symbol.trim().isEmpty ||
        symbol.contains(RegExp(r'[\r\n]')) ||
        skip < 0 ||
        take < 1 ||
        take > 100) {
      throw const FormatException('Invalid holding activity filters');
    }
    final json = await _get(
      serverUrl,
      jwt,
      '/api/v1/activities',
      queryParameters: {
        'skip': '$skip',
        'take': '$take',
        'sortColumn': 'date',
        'sortDirection': 'desc',
        'dataSource': dataSource,
        'symbol': symbol,
      },
    );
    return ActivityBatch.fromJson(json);
  }

  Future<Map<String, dynamic>> _get(
    String serverUrl,
    String jwt,
    String path, {
    String? range,
    Map<String, String>? queryParameters,
  }) async {
    if (jwt.isEmpty || jwt.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid session token');
    }
    final uri = ServerClient.infoUri(serverUrl).replace(
      path: path,
      queryParameters: queryParameters == null && range == null
          ? null
          : {...?queryParameters, 'range': ?range},
    );
    final client = _clientFactory();
    try {
      return await _fetch(client, uri, jwt).timeout(_timeout);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _fetch(
    http.Client client,
    Uri uri,
    String jwt,
  ) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers[HttpHeaders.acceptHeader] = 'application/json'
      ..headers[HttpHeaders.authorizationHeader] = 'Bearer $jwt';
    final response = await client.send(request);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw PortfolioApiException(
        'Session expired or access denied',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw PortfolioApiException(
        'Request failed (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    if (response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase() !=
        'application/json') {
      throw const FormatException('Invalid API content type');
    }
    if (response.contentLength != null &&
        response.contentLength! > _maxResponseBytes) {
      throw const FormatException('API response too large');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw const FormatException('API response too large');
      }
      bytes.addAll(chunk);
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response');
    }
    return data;
  }
}
