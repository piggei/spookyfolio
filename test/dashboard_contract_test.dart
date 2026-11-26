import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spookyfolio/portfolio_client.dart';

Map<String, dynamic> fixture([String name = 'dashboard_portfolio']) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('complete details extend existing holdings and summary without losing fields', () {
    final snapshot = PortfolioSnapshot.fromJson(fixture());
    expect(snapshot.holdings, hasLength(5));
    expect(snapshot.holdings.first.symbol, 'FUND');
    expect(snapshot.holdings.first.value, 600);
    expect(snapshot.holdings.first.allocation, .6);
    final asset = snapshot.holdings.first.assetProfile!;
    expect(asset.currency, 'USD');
    expect(asset.assetClass, 'EQUITY');
    expect(asset.assetClassLabel, 'Equities');
    expect(asset.assetSubClass, 'ETF');
    expect(asset.assetSubClassLabel, 'ETF');
    expect(asset.isin, 'TEST00000001');
    expect(asset.countries!.first.code, 'US');
    expect(asset.countries!.first.continent, 'North America');
    expect(asset.countries!.first.weight, .75);
    expect(asset.sectors!.first.weight, .8);
    expect(asset.holdings!.first.valueInBaseCurrency, 60);
    expect(snapshot.holdings.first.markets!['developedMarkets'], 1);
    expect(snapshot.holdings.first.marketsAdvanced!['northAmerica'], .75);
    expect(snapshot.createdAt, DateTime.utc(2026, 11, 23, 12));
    expect(snapshot.netWorth, 2000);
    expect(snapshot.investedValue, 750);
    expect(snapshot.summary!.filteredValueInPercentage, .5);
    expect(snapshot.summary!.totalInvestmentValueWithCurrencyEffect, 780);
    expect(snapshot.summary!.totalAssetsInBaseCurrency, 2200);
    expect(snapshot.accounts!.values.first.currency, 'USD');
    expect(snapshot.accounts!.values.first.quantity, 2);
    expect(snapshot.platforms!.values.single.name, 'Platform');
    expect(snapshot.markets!['developedMarkets']!.valueInPercentage, .8);
  });

  for (final accountId in [null, '11111111-2222-3333-4444-555555555555']) {
    for (final withMarkets in [true, false]) {
      test(
        'allocation request preserves account filter $accountId and withMarkets=$withMarkets',
        () async {
          var calls = 0;
          final api = PortfolioClient(
            clientFactory: () => MockClient((request) async {
              calls++;
              expect(request.url.path, '/api/v1/portfolio/details');
              expect(request.headers['authorization'], 'Bearer test-jwt');
              expect(request.followRedirects, isFalse);
              expect(request.url.queryParameters, {
                'withMarkets': '$withMarkets',
                'accounts': ?accountId,
              });
              final body = fixture();
              if (accountId != null) {
                body['accounts'] = {accountId: body['accounts'][accountId]};
              }
              return http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          final result = await api.getAllocationDetails(
            serverUrl: 'https://ghostfol.io',
            jwt: 'test-jwt',
            accountId: accountId,
            withMarkets: withMarkets,
          );
          expect(calls, 1);
          expect(result.accounts, hasLength(accountId == null ? 2 : 1));
        },
      );
    }
  }

  test(
    'default allocation request opts into markets; old requests stay unchanged',
    () async {
      final queries = <Map<String, String>>[];
      final api = PortfolioClient(
        clientFactory: () => MockClient((request) async {
          queries.add(request.url.queryParameters);
          return http.Response(
            '{"holdings":[]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await api.getAllocationDetails(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
      );
      await api.getDetails(serverUrl: 'https://ghostfol.io', jwt: 'jwt');
      await api.getDetailsForAccount(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        accountId: '11111111-2222-3333-4444-555555555555',
      );
      expect(queries, [
        {'withMarkets': 'true'},
        {},
        {'accounts': '11111111-2222-3333-4444-555555555555'},
      ]);
    },
  );

  test('invalid allocation account never makes a request', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('Unexpected request');
      }),
    );
    await expectLater(
      api.getAllocationDetails(
        serverUrl: 'https://ghostfol.io',
        jwt: 'jwt',
        accountId: 'invalid',
      ),
      throwsFormatException,
    );
  });

  test('allocation requests reuse status and content validation', () async {
    for (final status in [401, 403, 500]) {
      final api = PortfolioClient(
        clientFactory: () => MockClient((_) async => http.Response('', status)),
      );
      await expectLater(
        api.getAllocationDetails(serverUrl: 'https://ghostfol.io', jwt: 'jwt'),
        throwsA(isA<PortfolioApiException>()),
      );
    }
  });

  test('restricted details keep percentage and monetary channels separate', () {
    final snapshot = PortfolioSnapshot.fromJson(
      fixture('dashboard_portfolio_restricted'),
    );
    expect(snapshot.netWorth, isNull);
    expect(snapshot.holdings.first.value, isNull);
    expect(snapshot.holdings.first.valueInPercentage, .6);
    expect(snapshot.accounts!.values.first.valueInBaseCurrency, isNull);
    expect(snapshot.accounts!.values.first.valueInPercentage, .7);
    expect(snapshot.markets!.values.first.valueInBaseCurrency, isNull);
    expect(
      snapshot.holdings.first.assetProfile!.holdings!.first.valueInBaseCurrency,
      isNull,
    );
    expect(snapshot.summary!.filteredValueInPercentage, .5);
  });

  test(
    'legacy minimal and empty responses preserve missing versus empty metadata',
    () {
      final minimal = PortfolioSnapshot.fromJson({'holdings': []});
      expect(minimal.accounts, isNull);
      expect(minimal.markets, isNull);
      expect(minimal.summary, isNull);
      final empty = PortfolioSnapshot.fromJson({
        'holdings': [],
        'accounts': <String, dynamic>{},
        'platforms': <String, dynamic>{},
        'markets': <String, dynamic>{},
        'summary': {'currentNetWorth': 0},
      });
      expect(empty.accounts, isEmpty);
      expect(empty.markets, isEmpty);
      expect(empty.netWorth, 0);
      expect(empty.summary!.currentNetWorth, 0);
    },
  );

  test('optional upstream holding names use a display fallback while retaining absent metadata', () {
    final snapshot = PortfolioSnapshot.fromJson({
      'holdings': [
        {
          'assetProfile': {'symbol': 'ETF', 'assetSubClass': 'ETF'},
          'valueInBaseCurrency': 10,
        },
      ],
    });
    expect(snapshot.holdings.single.name, 'ETF');
    expect(snapshot.holdings.single.assetProfile!.name, isNull);
    expect(
      () => PortfolioSnapshot.fromJson({
        'holdings': [
          {
            'assetProfile': {'symbol': 'X', 'name': 123},
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('absent classifications remain nullable', () {
    final snapshot = PortfolioSnapshot.fromJson({
      'holdings': [
        {
          'assetProfile': {'symbol': 'X', 'name': 'Asset'},
        },
      ],
    });
    final asset = snapshot.holdings.single.assetProfile!;
    expect(asset.assetClass, isNull);
    expect(asset.countries, isNull);
    expect(asset.holdings, isNull);
    expect(snapshot.holdings.single.value, isNull);
  });

  test(
    'reject malformed classification shapes and non-finite numeric fields',
    () {
      for (final field in ['countries', 'sectors', 'holdings']) {
        final body = fixture();
        body['holdings'][0]['assetProfile'][field] = {};
        expect(() => PortfolioSnapshot.fromJson(body), throwsFormatException);
      }
      for (final raw in [double.nan, double.infinity, '1']) {
        final body = fixture();
        body['holdings'][0]['assetProfile']['countries'][0]['weight'] = raw;
        expect(() => PortfolioSnapshot.fromJson(body), throwsFormatException);
        final summary = fixture();
        summary['summary']['filteredValueInPercentage'] = raw;
        expect(
          () => PortfolioSnapshot.fromJson(summary),
          throwsFormatException,
        );
      }
      for (final field in [
        'accounts',
        'platforms',
        'markets',
        'marketsAdvanced',
      ]) {
        final body = fixture();
        body[field] = [];
        expect(() => PortfolioSnapshot.fromJson(body), throwsFormatException);
      }
      final invalid = fixture();
      invalid['createdAt'] = 'not-a-date';
      expect(() => PortfolioSnapshot.fromJson(invalid), throwsFormatException);
    },
  );

}
