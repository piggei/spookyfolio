import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spookyfolio/portfolio_client.dart';
import 'package:spookyfolio/portfolio_allocations.dart';

Map<String, dynamic> fixture([bool restricted = false]) => jsonDecode(
  File(
    'test/fixtures/dashboard_portfolio${restricted ? '_restricted' : ''}.json',
  ).readAsStringSync(),
) as Map<String, dynamic>;
PortfolioAllocations aggregate(
  Map<String, dynamic> json, [
  AllocationUnit unit = AllocationUnit.baseCurrency,
]) => PortfolioAllocations.fromSnapshot(
  PortfolioSnapshot.fromJson(json),
  unit: unit,
  baseCurrency: 'EUR',
);
AllocationBucket bucket(AllocationBreakdown data, String key) =>
    data.buckets.singleWhere((item) => item.id == key);

void main() {
  test('complete portfolio supports all allocation representations without a widget', () {
    final result = aggregate(fixture());
    expect(result.baseCurrency, 'EUR');
    expect(result.proportionOfNetWorth, .5);
    expect(result.byPlatform.total, 1000);
    expect(result.byAccount.total, 1000);
    expect(result.byCurrency.total, 1000);
    expect(result.byAssetClass.total, 1000);
    expect(result.byHolding.total, 1000);
    expect(result.byEtfProvider.total, 1000);
    expect(result.bySector.total, 900);
    expect(result.byContinent.total, 900);
    expect(result.byCountry.total, 900);
    expect(result.worldMap.total, 900);
    expect(result.byMarket.total, 1000);
    expect(result.regions.total, 1000);
    expect(result.byEtfHolding.holdings, hasLength(3));
    expect(result.byCountry.unit, AllocationUnit.baseCurrency);
    expect(result.byCountry.basis, AllocationBasis.nonCashHoldings);
  });

  test('cash is excluded only from geographical and sector exposure', () {
    final result = aggregate(fixture());
    expect(bucket(result.byCountry, 'US').value, 450);
    expect(bucket(result.byCountry, 'DE').value, 350);
    expect(bucket(result.byContinent, 'North America').value, 450);
    expect(bucket(result.bySector, 'Technology').value, 580);
    expect(bucket(result.bySector, 'Financials').value, 220);
    expect(bucket(result.byCountry, unknownAllocation).value, 100);
    expect(bucket(result.byCurrency, 'EUR').value, 100);
    expect(bucket(result.byHolding, 'EUR').value, 100);
    // Commodity/crypto currency is UNKNOWN even though the quoted currency is USD.
    expect(bucket(result.byCurrency, 'USD').value, 800);
    expect(bucket(result.byCurrency, unknownAllocation).value, 100);
    expect(bucket(result.byEtfProvider, unknownAllocation).value, 200);
  });

  test('class and subclass labels group hierarchically', () {
    final result = aggregate(fixture());
    final equities = bucket(result.byAssetClass, 'EQUITY');
    expect(equities.value, 800);
    expect(equities.children.single.id, 'ETF');
    expect(equities.children.single.value, 800);
    final body = fixture();
    body['holdings'][0]['assetProfile'].remove('assetClassLabel');
    body['holdings'][0]['assetProfile'].remove('assetSubClassLabel');
    final identified = bucket(aggregate(body).byAssetClass, 'EQUITY');
    expect(identified.value, 800);
    expect(identified.children.single.id, 'ETF');
    expect(
      identified.label,
      'EQUITY',
    ); // Stable code remains usable without a label.
    body['holdings'][0]['assetProfile'].remove('assetClass');
    body['holdings'][0]['assetProfile'].remove('assetSubClass');
    expect(bucket(aggregate(body).byAssetClass, unknownAllocation).value, 600);
  });

  test('an unnamed ETF is not classified under a fabricated provider', () {
    final body = fixture();
    body['holdings'][0]['assetProfile'].remove('name');
    final result = aggregate(body);
    expect(bucket(result.byEtfProvider, unknownAllocation).value, 800);
    expect(
      result.byEtfProvider.buckets.any((item) => item.id == 'FUND'),
      isFalse,
    );
  });

  test('symbols aggregate across sources while retaining their identities', () {
    final result = aggregate(fixture());
    final fund = bucket(result.byHolding, 'FUND');
    expect(fund.value, 800);
    expect(fund.dataSources, {'YAHOO', 'MANUAL'});
    expect(result.byHolding.buckets, hasLength(4));
    expect(bucket(result.byEtfProvider, 'iShares').value, 600);
    expect(bucket(result.byEtfProvider, 'Vanguard').value, 200);
  });

  test(
    'restricted exposure uses non-cash denominator instead of whole portfolio',
    () {
      final result = aggregate(fixture(true), AllocationUnit.fraction);
      expect(result.byCountry.unit, AllocationUnit.fraction);
      expect(bucket(result.byCountry, 'US').value, closeTo(.5, 1e-14));
      expect(bucket(result.byCountry, 'DE').value, closeTo(.35 / .9, 1e-14));
      expect(
        bucket(result.bySector, 'Technology').value,
        closeTo(.58 / .9, 1e-14),
      );
      expect(
        bucket(result.byCountry, unknownAllocation).value,
        closeTo(.1 / .9, 1e-14),
      );
      expect(bucket(result.byCurrency, 'EUR').value, .1);
      expect(bucket(result.byHolding, 'FUND').value, .8);
      expect(result.byAccount.total, 1);
      expect(result.byEtfHolding.unit, AllocationUnit.fraction);
    },
  );

  test('incomplete weights are not blindly normalized and Regions retain raw country data', () {
    final body = fixture(true);
    body['holdings'][0]['assetProfile']['countries'] = [
      {'code': 'US', 'continent': 'North America', 'weight': .5},
    ];
    final result = aggregate(body, AllocationUnit.fraction);
    expect(bucket(result.worldMap, 'US').value, closeTo(.3 / .9, 1e-14));
    expect(result.worldMap.total, isNull);
    expect(result.worldMap.bucketTotal, closeTo(.6 / .9, 1e-14));
    // A proportion chart adds a residual UNKNOWN slice; it does not scale known countries.
    expect(
      bucket(result.byCountry, 'US').value,
      bucket(result.worldMap, 'US').value,
    );
    expect(result.byCountry.hasIncompleteClassifications, isFalse);
    expect(result.byCountry.total, closeTo(1, 1e-14));
    expect(result.byCountry.bucketTotal, closeTo(1, 1e-14));
    final money = fixture();
    money['holdings'][0]['assetProfile']['countries'] = [
      {'code': 'US', 'continent': 'North America', 'weight': .5},
    ];
    expect(aggregate(money).byCountry.total, 900);
    expect(aggregate(money).byCountry.bucketTotal, 900);
    expect(aggregate(money).worldMap.bucketTotal, 600);
  });

  test('overweight and negligible fractional shortfalls are preserved', () {
    final body = fixture(true);
    body['holdings'] = [body['holdings'][0]];
    body['holdings'][0]['allocationInPercentage'] = 1.2;
    var result = aggregate(body, AllocationUnit.fraction);
    expect(result.byCurrency.total, 1.2);
    expect(result.byCurrency.buckets, hasLength(1));
    body['holdings'][0]['allocationInPercentage'] = .99999;
    result = aggregate(body, AllocationUnit.fraction);
    expect(result.byCurrency.total, .99999);
    expect(result.byCurrency.buckets, hasLength(1));
  });

  test('markets use server totals and keep basic and advanced classifications distinct', () {
    final body = fixture();
    body['markets']['UNKNOWN']['valueInPercentage'] = .1;
    body['marketsAdvanced']['UNKNOWN']['valueInPercentage'] = .1;
    final result = aggregate(body, AllocationUnit.fraction);
    expect(result.regions.total, closeTo(.9, 1e-14));
    expect(result.byMarket.total, closeTo(1, 1e-14));
    expect(bucket(result.regions, 'developedMarkets').value, .8);
    expect(bucket(result.byMarket, 'northAmerica').value, .45);
    expect(result.regions.basis, AllocationBasis.serverMarkets);
  });

  test('missing monetary values never become zero or percentage amounts', () {
    final restricted = aggregate(fixture(true));
    expect(bucket(restricted.byHolding, 'FUND').value, isNull);
    expect(restricted.byCountry.total, isNull);
    expect(restricted.byAccount.total, isNull);
    expect(restricted.byMarket.total, isNull);
    expect(
      restricted.byEtfHolding.holdings.every((item) => item.value == null),
      isTrue,
    );
    final body = fixture();
    body['holdings'][1]['valueInBaseCurrency'] = null;
    final result = aggregate(body);
    expect(bucket(result.byHolding, 'FUND').value, isNull); // not a partial 600
    expect(bucket(result.byCurrency, 'EUR').value, 100);
    expect(result.byEtfHolding.coveredFundValue, isNull);
    expect(result.byEtfHolding.holdings.first.allocationInPercentage, isNull);
  });

  test('missing weights propagate as unavailable rather than zero', () {
    final body = fixture();
    body['holdings'][0]['assetProfile']['countries'][0]['weight'] = null;
    body['holdings'][0]['assetProfile']['sectors'][0].remove('weight');
    final result = aggregate(body);
    expect(bucket(result.byCountry, 'US').value, isNull);
    expect(bucket(result.byCountry, 'DE').value, 350);
    expect(bucket(result.bySector, 'Technology').value, isNull);
  });

  test(
    'no classifications yield explicit UNKNOWN without guessing from symbol',
    () {
      final body = fixture();
      body['holdings'] = [
        {
          'assetProfile': {'symbol': 'EUR', 'name': 'Unclassified'},
          'valueInBaseCurrency': 40,
        },
      ];
      final result = aggregate(body);
      expect(bucket(result.byCurrency, unknownAllocation).value, 40);
      expect(bucket(result.byCountry, unknownAllocation).value, 40);
      expect(bucket(result.byContinent, unknownAllocation).value, 40);
      expect(bucket(result.bySector, unknownAllocation).value, 40);
      expect(bucket(result.byAssetClass, unknownAllocation).value, 40);
    },
  );

  test('ETF holdings use composition weights, name normalization and covered-funds denominator', () {
    final result = aggregate(fixture());
    final etfs = result.byEtfHolding;
    final apple = etfs.holdings.singleWhere((item) => item.name == 'Apple Inc');
    expect(etfs.isExperimental, isTrue);
    expect(etfs.isApproximate, isTrue);
    expect(etfs.coveredFundValue, 800);
    expect(etfs.basis, AllocationBasis.fundsWithComposition);
    expect(apple.value, 100);
    expect(apple.allocationInPercentage, .125);
    expect(apple.parents, hasLength(2));
    expect(apple.parents.map((p) => p.fractionOfHolding), [.6, .4]);
    expect(
      etfs.holdings.fold<double>(
        0,
        (sum, h) => sum + h.allocationInPercentage!,
      ),
      .1875,
    );
    final restricted = aggregate(
      fixture(true),
      AllocationUnit.fraction,
    ).byEtfHolding;
    final fraction = restricted.holdings.singleWhere(
      (item) => item.name == 'Apple Inc',
    );
    expect(restricted.basis, AllocationBasis.portfolio);
    expect(fraction.value, .1);
    expect(fraction.allocationInPercentage, .1); // never .125 or 100%
  });

  test('missing ETF composition is explicit and never reconstructed', () {
    final body = fixture();
    body['holdings'][0]['assetProfile']['holdings'] = [];
    body['holdings'][1]['assetProfile'].remove('holdings');
    final result = aggregate(body).byEtfHolding;
    expect(result.holdings, isEmpty);
    expect(result.positionsWithoutComposition, ['YAHOO:FUND', 'MANUAL:FUND']);
    expect(result.coveredFundValue, 0);
  });

  test('missing underlying money cannot be replaced by known percentage weights', () {
    final body = fixture();
    body['holdings'][0]['assetProfile']['holdings'][0]['valueInBaseCurrency'] =
        null;
    final result = aggregate(body).byEtfHolding;
    final apple = result.holdings.singleWhere(
      (item) => item.name == 'Apple Inc',
    );
    expect(apple.value, isNull);
    expect(apple.allocationInPercentage, isNull);
  });

  test('ETF analyses retain upstream top-50 cap without renormalizing', () {
    final body = fixture();
    body['holdings'] = [body['holdings'][0]];
    body['holdings'][0]['assetProfile']['holdings'] = [
      for (var i = 1; i <= 60; i++)
        {
          'name': 'Asset $i',
          'allocationInPercentage': i / 10000,
          'valueInBaseCurrency': i.toDouble(),
        },
    ];
    final result = aggregate(body).byEtfHolding;
    expect(result.holdings, hasLength(50));
    expect(result.holdings.first.value, 60);
    expect(result.holdings.last.value, 11);
    expect(result.holdings.first.allocationInPercentage, .1);
  });

  test('empty versus omitted metadata remains distinguishable without fabricated exposure', () {
    final result = aggregate({
      'holdings': [],
      'accounts': <String, dynamic>{},
      'platforms': <String, dynamic>{},
      'markets': <String, dynamic>{},
      'marketsAdvanced': <String, dynamic>{},
      'summary': {'filteredValueInPercentage': 0},
    }, AllocationUnit.fraction);
    expect(result.byHolding.buckets, isEmpty);
    expect(result.byCountry.buckets, isEmpty);
    expect(result.byAccount.isAvailable, isTrue);
    expect(result.byAccount.isComplete, isTrue);
    expect(result.byCountry.isComplete, isTrue);
    expect(result.byAccount.total, 0);
    expect(result.byEtfHolding.holdings, isEmpty);
    expect(result.proportionOfNetWorth, 0);
    final unavailable = aggregate({'holdings': []});
    expect(unavailable.byAccount.isAvailable, isFalse);
    expect(unavailable.byAccount.isComplete, isFalse);
    expect(unavailable.byAccount.hasUnavailableValues, isTrue);
    expect(unavailable.byAccount.total, isNull);
    expect(unavailable.regions.isAvailable, isFalse);
    expect(unavailable.proportionOfNetWorth, isNull);
  });

  test('cash-only portfolio has no geographical or sector exposures', () {
    final body = fixture(true);
    body['holdings'] = [body['holdings'][2]];
    final result = aggregate(body, AllocationUnit.fraction);
    expect(result.byCountry.buckets, isEmpty);
    expect(result.bySector.buckets, isEmpty);
    expect(bucket(result.byCurrency, 'EUR').value, .1);
  });

  test('account/platform amounts use supplied base-currency totals, never native balances', () {
    final body = fixture();
    body['accounts']['aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee']['balance'] =
        100000;
    final result = aggregate(body);
    expect(result.byAccount.total, 1000);
    expect(result.byPlatform.total, 1000);
    expect(
      bucket(result.byAccount, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee').value,
      300,
    );
  });

  test('account-filtered aggregation respects supplied totals and net-worth proportion', () {
    final body = fixture();
    body['holdings'] = [body['holdings'][0], body['holdings'][2]];
    final id = '11111111-2222-3333-4444-555555555555';
    body['accounts'] = {id: body['accounts'][id]};
    body['platforms']['broker']['valueInBaseCurrency'] = 700;
    body['summary']['filteredValueInBaseCurrency'] = 700;
    body['summary']['filteredValueInPercentage'] = .35;
    final result = aggregate(body);
    expect(result.byAccount.buckets, hasLength(1));
    expect(result.byAccount.total, 700);
    expect(result.byPlatform.total, 700);
    expect(result.byHolding.total, 700);
    expect(result.byCountry.total, 600);
    expect(result.proportionOfNetWorth, .35);
  });

  test('arithmetic overflow fails explicitly instead of returning invalid financial values', () {
    final body = fixture();
    body['holdings'] = [
      for (var i = 0; i < 2; i++)
        {
          'assetProfile': {'symbol': 'X', 'name': 'X'},
          'valueInBaseCurrency': 1e308,
        },
    ];
    expect(() => aggregate(body), throwsFormatException);
  });

  test('complete classifications are distinct from quantified UNKNOWN contributions', () {
    final completeBody = fixture();
    completeBody['holdings'] = completeBody['holdings'].take(3).toList();
    // Cash classifications do not affect completeness of non-cash analyses.
    completeBody['holdings'][2]['assetProfile']['countries'][0]['weight'] =
        null;
    final complete = aggregate(completeBody);
    for (final view in [
      complete.byCountry,
      complete.byContinent,
      complete.bySector,
      complete.worldMap,
    ]) {
      expect(view.isComplete, isTrue);
      expect(view.hasUnknownContributions, isFalse);
      expect(view.hasIncompleteClassifications, isFalse);
      expect(view.hasUnavailableValues, isFalse);
      expect(view.total, 800);
    }
    final unclassified = aggregate(fixture());
    for (final view in [
      unclassified.byCountry,
      unclassified.byContinent,
      unclassified.bySector,
      unclassified.worldMap,
    ]) {
      expect(view.isComplete, isFalse);
      expect(view.hasUnknownContributions, isTrue);
      expect(view.hasUnavailableValues, isFalse);
      expect(view.hasIncompleteClassifications, isFalse);
      expect(
        view.total,
        900,
      ); // The UNKNOWN amount is known, not missing money.
    }
  });

  for (final unit in AllocationUnit.values) {
    test(
      'partial country coverage stays incomplete while sector and continent get quantified UNKNOWN in $unit',
      () {
        final body = fixture(unit == AllocationUnit.fraction);
        body['holdings'] = [body['holdings'][0]];
        body['holdings'][0]['assetProfile']['countries'] = [
          {
            'code': 'US',
            'name': 'United States',
            'continent': 'North America',
            'weight': .5,
          },
        ];
        body['holdings'][0]['assetProfile']['sectors'] = [
          {'name': 'Technology', 'weight': .5},
        ];
        final result = aggregate(body, unit);
        for (final view in [result.worldMap]) {
          expect(view.isComplete, isFalse);
          expect(view.hasIncompleteClassifications, isTrue);
          expect(view.hasUnavailableValues, isFalse);
          expect(view.total, isNull);
        }
        final expectedHalf = unit == AllocationUnit.fraction ? .5 : 300.0;
        final expectedWhole = unit == AllocationUnit.fraction ? 1.0 : 600.0;
        for (final view in [
          result.byCountry,
          result.byContinent,
          result.bySector,
        ]) {
          expect(view.hasIncompleteClassifications, isFalse);
          expect(view.hasUnknownContributions, isTrue);
          expect(view.isComplete, isFalse);
          expect(view.hasUnavailableValues, isFalse);
          expect(view.total, closeTo(expectedWhole, 1e-12));
          expect(
            bucket(view, unknownAllocation).value,
            closeTo(expectedHalf, 1e-12),
          );
        }
        expect(
          bucket(result.byCountry, 'US').value,
          closeTo(expectedHalf, 1e-12),
        );
        expect(result.worldMap.bucketTotal, closeTo(expectedHalf, 1e-12));
        expect(result.byCountry.bucketTotal, closeTo(expectedWhole, 1e-12));
        expect(result.worldMap.hasUnknownContributions, isFalse);
        expect(result.byCountry.hasUnknownContributions, isTrue);
      },
    );
  }

  test('unavailable weights and monetary values cannot masquerade as complete coverage', () {
    final body = fixture();
    body['holdings'] = body['holdings'].take(2).toList();
    body['holdings'][0]['assetProfile']['countries'][0]['weight'] = null;
    body['holdings'][0]['assetProfile']['sectors'][0].remove('weight');
    final missingWeights = aggregate(body);
    for (final view in [
      missingWeights.byCountry,
      missingWeights.byContinent,
      missingWeights.bySector,
      missingWeights.worldMap,
    ]) {
      expect(view.isComplete, isFalse);
      expect(view.hasIncompleteClassifications, isTrue);
      expect(view.hasUnavailableValues, isTrue);
      expect(view.total, isNull);
      expect(view.bucketTotal, isNull);
    }
    final missingMoney = fixture();
    missingMoney['holdings'] = missingMoney['holdings'].take(2).toList();
    missingMoney['holdings'][0]['valueInBaseCurrency'] = null;
    final result = aggregate(missingMoney);
    for (final view in [
      result.byCountry,
      result.byContinent,
      result.bySector,
    ]) {
      expect(view.hasIncompleteClassifications, isFalse);
      expect(view.hasUnavailableValues, isTrue);
      expect(view.isComplete, isFalse);
      expect(view.total, isNull);
    }
  });

  test(
    'underweight and overweight positions cannot cancel completeness errors',
    () {
      final body = fixture();
      body['holdings'] = body['holdings'].take(2).toList();
      for (var i = 0; i < 2; i++) {
        body['holdings'][i]['assetProfile']['countries'] = [
          {
            'code': 'US',
            'continent': 'North America',
            'weight': i == 0 ? .5 : 2.5,
          },
        ];
        body['holdings'][i]['assetProfile']['sectors'] = [
          {'name': 'Technology', 'weight': i == 0 ? .5 : 2.5},
        ];
      }
      final result = aggregate(body);
      final map = result.worldMap;
      expect(map.bucketTotal, 800);
      expect(map.hasIncompleteClassifications, isTrue);
      expect(map.hasUnknownContributions, isFalse);
      expect(map.isComplete, isFalse);
      expect(map.total, isNull);
      for (final view in [
        result.byCountry,
        result.byContinent,
        result.bySector,
      ]) {
        // The quantified 300 remainder of the first position is visible,
        // but the second position is overweight, so no valid total exists.
        expect(view.bucketTotal, 1100);
        expect(bucket(view, unknownAllocation).value, 300);
        expect(view.hasIncompleteClassifications, isTrue);
        expect(view.hasUnknownContributions, isTrue);
        expect(view.isComplete, isFalse);
        expect(view.total, isNull);
      }
    },
  );

  test('small coverage gaps are retained as quantified UNKNOWN for sector and continent', () {
    final body = fixture(true);
    body['holdings'] = [body['holdings'][0]];
    body['holdings'][0]['assetProfile']['countries'] = [
      {'code': 'US', 'continent': 'North America', 'weight': .99999},
    ];
    body['holdings'][0]['assetProfile']['sectors'] = [
      {'name': 'Technology', 'weight': .99999},
    ];
    final result = aggregate(body, AllocationUnit.fraction);
    for (final view in [
      result.byCountry,
      result.byContinent,
      result.bySector,
    ]) {
      expect(view.hasUnknownContributions, isTrue);
      expect(view.hasIncompleteClassifications, isFalse);
      expect(view.isComplete, isFalse);
      expect(view.total, closeTo(1, 1e-14));
      expect(bucket(view, unknownAllocation).value, closeTo(.00001, 1e-14));
    }
    for (final holding in body['holdings']) {
      holding['assetProfile']['countries'] = [
        for (final weight in [.1, .2, .7])
          {'code': 'US', 'continent': 'North America', 'weight': weight},
      ];
      holding['assetProfile']['sectors'] = [
        for (final weight in [.1, .2, .7])
          {'name': 'Technology', 'weight': weight},
      ];
    }
    final complete = aggregate(body, AllocationUnit.fraction);
    expect(complete.byCountry.isComplete, isTrue);
    expect(complete.byContinent.isComplete, isTrue);
    expect(complete.bySector.isComplete, isTrue);
  });

  test('cash without a server-defined subclass has no synthetic child', () {
    final body = fixture();
    final cash = body['holdings'][2]['assetProfile'] as Map<String, dynamic>;
    cash.remove('assetSubClass');
    cash.remove('assetSubClassLabel');
    final result = aggregate(body);
    final liquidity = bucket(result.byAssetClass, 'LIQUIDITY');
    expect(liquidity.value, 100);
    expect(liquidity.children, isEmpty);
    expect(result.byAssetClass.total, 1000);
  });

  for (final unit in AllocationUnit.values) {
    test(
      'provider rounding noise permits sector and continent donut data in $unit',
      () {
        final body = fixture(unit == AllocationUnit.fraction);
        body['holdings'] = [body['holdings'][0]];
        final asset = body['holdings'][0]['assetProfile'];
        asset['countries'] = [
          {'code': 'US', 'continent': 'North America', 'weight': 1.000000023},
        ];
        asset['sectors'] = [
          {'name': 'Technology', 'weight': 0.999999991},
        ];
        final result = aggregate(body, unit);
        for (final view in [result.byContinent, result.bySector]) {
          expect(view.hasIncompleteClassifications, isFalse);
          expect(view.hasUnavailableValues, isFalse);
          expect(view.total, isNotNull);
          expect(view.buckets.where((b) => b.id == unknownAllocation), isEmpty);
        }
        // Country chart tolerates provider noise; raw map retains its original completeness contract.
        expect(result.byCountry.hasIncompleteClassifications, isFalse);
        expect(result.worldMap.hasIncompleteClassifications, isTrue);
        final base = unit == AllocationUnit.fraction ? 1.0 : 600.0;
        expect(result.byContinent.total, closeTo(base * 1.000000023, 1e-5));
        expect(result.bySector.total, closeTo(base * 0.999999991, 1e-5));
      },
    );
  }

  test('material overweight remains invalid while material underweight gets Unknown', () {
    final body = fixture();
    body['holdings'] = [body['holdings'][0]];
    final asset = body['holdings'][0]['assetProfile'];
    asset['countries'] = [
      {'code': 'US', 'continent': 'North America', 'weight': 1.02},
    ];
    asset['sectors'] = [
      {'name': 'Technology', 'weight': 0.95},
    ];
    final result = aggregate(body);
    expect(result.byContinent.hasIncompleteClassifications, isTrue);
    expect(result.byContinent.total, isNull);
    expect(result.bySector.hasIncompleteClassifications, isFalse);
    expect(bucket(result.bySector, unknownAllocation).value, closeTo(30, 1e-9));
    expect(result.bySector.total, closeTo(600, 1e-9));
  });

  test('stable account platform and market identifiers retain exact spelling and case', () {
    final body = fixture();
    body['accounts'] = {
      'accountKey': {'name': 'Shared label', 'valueInBaseCurrency': 10},
      'ACCOUNTKEY': {'name': 'Shared label', 'valueInBaseCurrency': 20},
    };
    body['platforms'] = {
      'brokerKey': {'name': 'Shared label', 'valueInBaseCurrency': 30},
      'BROKERKEY': {'name': 'Shared label', 'valueInBaseCurrency': 40},
    };
    body['marketsAdvanced'] = {
      'northAmerica': {'id': 'northAmerica', 'valueInBaseCurrency': 50},
      'NORTHAMERICA': {'id': 'NORTHAMERICA', 'valueInBaseCurrency': 60},
    };
    final result = aggregate(body);
    expect(bucket(result.byAccount, 'accountKey').value, 10);
    expect(bucket(result.byAccount, 'ACCOUNTKEY').value, 20);
    expect(bucket(result.byPlatform, 'brokerKey').value, 30);
    expect(bucket(result.byPlatform, 'BROKERKEY').value, 40);
    expect(bucket(result.byMarket, 'northAmerica').value, 50);
    expect(bucket(result.byMarket, 'NORTHAMERICA').value, 60);
    expect(result.byAccount.buckets.map((item) => item.label).toSet(), {
      'Shared label',
    });
  });

  test('class and subclass identifiers are independent of shared or localized labels', () {
    final body = fixture();
    body['holdings'] = body['holdings'].take(2).toList();
    body['holdings'][0]['assetProfile']['assetClassLabel'] = 'Assets';
    body['holdings'][1]['assetProfile']['assetClassLabel'] = 'Assets';
    body['holdings'][1]['assetProfile']['assetClass'] = 'FIXED_INCOME';
    var result = aggregate(body);
    expect(result.byAssetClass.buckets.map((item) => item.id).toSet(), {
      'EQUITY',
      'FIXED_INCOME',
    });
    expect(result.byAssetClass.buckets.map((item) => item.label).toSet(), {
      'Assets',
    });
    body['holdings'][1]['assetProfile']['assetClass'] = 'EQUITY';
    body['holdings'][1]['assetProfile']['assetClassLabel'] = 'Localized equity';
    body['holdings'][0]['assetProfile']['assetSubClassLabel'] = 'Fund';
    body['holdings'][1]['assetProfile']['assetSubClassLabel'] = 'Fund';
    body['holdings'][1]['assetProfile']['assetSubClass'] = 'MUTUALFUND';
    result = aggregate(body);
    final equity = bucket(result.byAssetClass, 'EQUITY');
    expect(equity.value, 800);
    expect(equity.children.map((item) => item.id).toSet(), {
      'ETF',
      'MUTUALFUND',
    });
    expect(equity.children.map((item) => item.label).toSet(), {'Fund'});
  });

  test('case-distinct symbols and label-only classifications are not silently merged', () {
    final body = fixture();
    body['holdings'] = body['holdings'].take(2).toList();
    for (var i = 0; i < 2; i++) {
      body['holdings'][i]['assetProfile']['symbol'] = i == 0 ? 'Fund' : 'FUND';
      body['holdings'][i]['assetProfile'].remove('assetClass');
      body['holdings'][i]['assetProfile']['assetClassLabel'] = i == 0
          ? 'Funds'
          : 'FUNDS';
      body['holdings'][i]['assetProfile']['countries'] = [
        {
          'code': i == 0 ? 'US' : 'DE',
          'name': 'Shared country label',
          'continent': 'Europe',
          'weight': 1,
        },
      ];
      body['holdings'][i]['assetProfile']['sectors'] = [
        {'name': i == 0 ? 'Technology' : 'TECHNOLOGY', 'weight': 1},
      ];
    }
    final result = aggregate(body);
    expect(bucket(result.byHolding, 'Fund').value, 600);
    expect(bucket(result.byHolding, 'FUND').value, 200);
    expect(result.byAssetClass.buckets.map((item) => item.id).toSet(), {
      'Funds',
      'FUNDS',
    });
    expect(result.byCountry.buckets.map((item) => item.id).toSet(), {
      'US',
      'DE',
    });
    expect(result.byCountry.buckets.map((item) => item.label).toSet(), {
      'Shared country label',
    });
    expect(bucket(result.bySector, 'Technology').value, 600);
    expect(bucket(result.bySector, 'TECHNOLOGY').value, 200);
    // Exact symbols across sources and intentional normalized ETF names remain
    // covered by the existing aggregation regressions.
  });

  test('aggregation retains small values with no intermediate rounding', () {
    final body = fixture();
    body['holdings'] = [
      for (final v in [1e16, 1.0, -1e16])
        {
          'assetProfile': {'symbol': 'SAME', 'name': 'Same', 'currency': 'USD'},
          'valueInBaseCurrency': v,
        },
    ];
    final result = aggregate(body);
    expect(bucket(result.byHolding, 'SAME').value, 1);
    expect(bucket(result.byCurrency, 'USD').value, 1);
  });
  test(
    'missing country continent or sector identifiers flag only that breakdown',
    () {
      for (final missing in ['code', 'continent', 'sector']) {
        final body = fixture();
        body['holdings'] = [body['holdings'][0]];
        body['holdings'][0]['assetProfile']['countries'] = [
          {
            if (missing != 'code') 'code': 'US',
            if (missing != 'continent') 'continent': 'North America',
            'weight': 1,
          },
        ];
        body['holdings'][0]['assetProfile']['sectors'] = [
          {if (missing != 'sector') 'name': 'Technology', 'weight': 1},
        ];
        final result = aggregate(body);
        final views = {
          'code': result.byCountry,
          'continent': result.byContinent,
          'sector': result.bySector,
        };
        for (final entry in views.entries) {
          expect(entry.value.hasUnknownContributions, entry.key == missing);
          expect(entry.value.isComplete, entry.key != missing);
          expect(entry.value.hasIncompleteClassifications, isFalse);
          expect(entry.value.hasUnavailableValues, isFalse);
          expect(entry.value.total, 600);
        }
      }
    },
  );
}
