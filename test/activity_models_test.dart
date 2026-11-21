import 'package:flutter_test/flutter_test.dart';
import 'package:spookyfolio/activity_models.dart';

void main() {
  test('parses upstream activities with original amounts', () {
    final batch = ActivityBatch.fromJson({
      'count': 1,
      'activities': [
        {
          'id': 'activity-1',
          'date': '2026-11-16T00:00:00.000Z',
          'type': 'BUY',
          'currency': 'EUR',
          'quantity': 1,
          'unitPrice': 169.10,
          'fee': 0,
          'value': 169.10,
          'assetProfile': {'symbol': 'VWCE.MI', 'name': 'Vanguard ETF'},
          'account': {'name': 'My account'},
        },
      ],
    });
    expect(batch.count, 1);
    final a = batch.activities.single;
    expect(a.symbol, 'VWCE.MI');
    expect(a.value, 169.10);
    expect(a.fee, 0);
    expect(a.accountName, 'My account');
    expect(a.date.year, 2026);
  });

  test('cash movements do not require an asset profile', () {
    final batch = ActivityBatch.fromJson({
      'count': 1,
      'activities': [
        {
          'id': 'cash-1',
          'date': '2026-11-21',
          'type': 'DEPOSIT',
          'value': 100.0,
        },
      ],
    });
    expect(batch.activities.single.symbol, isNull);
    expect(batch.activities.single.value, 100);
  });

  test('rejects malformed or nonfinite activity amounts', () {
    expect(
      () => ActivityBatch.fromJson({
        'count': 1,
        'activities': [
          {
            'id': 'a',
            'date': '2026-11-21',
            'type': 'BUY',
            'fee': double.infinity,
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => ActivityBatch.fromJson({'count': '1', 'activities': []}),
      throwsFormatException,
    );
  });
}
