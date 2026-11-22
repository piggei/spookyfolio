import 'package:flutter_test/flutter_test.dart';
import 'package:spookyfolio/activity_models.dart';

void main() {
  const activityId = '11111111-2222-3333-4444-555555555555';

  Map<String, dynamic> activityJson() => {
    'id': activityId,
    'date': '2026-11-20T12:30:00.000Z',
    'type': 'BUY',
    'currency': 'EUR',
    'quantity': 2,
    'unitPrice': 100.25,
    'fee': 1.5,
    'value': 200.5,
    'valueInBaseCurrency': 210.75,
    'feeInBaseCurrency': 1.65,
    'feeInAssetProfileCurrency': 1.4,
    'unitPriceInAssetProfileCurrency': 98.5,
    'accountId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'comment': 'Long-term investment',
    'createdAt': '2026-11-20T13:00:00.000Z',
    'updatedAt': '2026-11-21T09:00:00.000Z',
    'assetProfile': {
      'name': 'Example ETF',
      'symbol': 'EXAMPLE',
      'dataSource': 'YAHOO',
      'currency': 'USD',
      'isin': 'IE0000000001',
    },
    'account': {'name': 'Brokerage'},
  };

  test('preserves extended activity fields', () {
    final activity = PortfolioActivity.fromJson(activityJson());

    expect(activity.id, activityId);
    expect(activity.dataSource, 'YAHOO');
    expect(activity.symbol, 'EXAMPLE');
    expect(activity.assetCurrency, 'USD');
    expect(activity.currency, 'EUR');
    expect(activity.isin, 'IE0000000001');
    expect(activity.accountName, 'Brokerage');
    expect(activity.comment, 'Long-term investment');
    expect(activity.value, 200.5);
    expect(activity.valueInBaseCurrency, 210.75);
    expect(activity.feeInBaseCurrency, 1.65);
    expect(activity.feeInAssetProfileCurrency, 1.4);
    expect(activity.unitPriceInAssetProfileCurrency, 98.5);
    expect(activity.createdAt, DateTime.utc(2026, 11, 20, 13));
    expect(activity.updatedAt, DateTime.utc(2026, 11, 21, 9));
  });

  test('preserves absent optional fields as null', () {
    final activity = PortfolioActivity.fromJson({
      'id': activityId,
      'date': '2026-11-20',
      'type': 'BUY',
    });

    expect(activity.dataSource, isNull);
    expect(activity.assetCurrency, isNull);
    expect(activity.isin, isNull);
    expect(activity.accountId, isNull);
    expect(activity.comment, isNull);
    expect(activity.valueInBaseCurrency, isNull);
    expect(activity.feeInBaseCurrency, isNull);
    expect(activity.feeInAssetProfileCurrency, isNull);
    expect(activity.unitPriceInAssetProfileCurrency, isNull);
    expect(activity.createdAt, isNull);
    expect(activity.updatedAt, isNull);
  });

  test('rejects malformed extended numeric fields', () {
    for (final field in [
      'valueInBaseCurrency',
      'feeInBaseCurrency',
      'feeInAssetProfileCurrency',
      'unitPriceInAssetProfileCurrency',
    ]) {
      final json = activityJson()..[field] = 'invalid';

      expect(() => PortfolioActivity.fromJson(json), throwsFormatException);
    }
  });

  test('rejects malformed extended dates', () {
    for (final field in ['createdAt', 'updatedAt']) {
      final json = activityJson()..[field] = 'invalid';

      expect(() => PortfolioActivity.fromJson(json), throwsFormatException);
    }
  });
}
