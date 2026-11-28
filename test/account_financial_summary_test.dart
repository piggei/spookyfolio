import 'package:flutter_test/flutter_test.dart';
import 'package:spookyfolio/account_financial_summary.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/portfolio_client.dart';

const accountId = '11111111-2222-3333-4444-555555555555';

PortfolioActivity activity(
  String id,
  String type, {
  double? fee,
  double? tax,
  double? value,
  bool draft = false,
}) => PortfolioActivity(
  id: id,
  date: DateTime.utc(2026, 1, 1),
  type: type,
  accountId: accountId,
  feeInBaseCurrency: fee,
  taxInBaseCurrency: tax,
  valueInBaseCurrency: value,
  isDraft: draft,
);

class SummaryClient extends PortfolioClient {
  SummaryClient(this.pages);
  final List<ActivityBatch> pages;
  int calls = 0;
  @override
  Future<ActivityBatch> getActivitiesForAccount({
    required String serverUrl,
    required String jwt,
    required String accountId,
    int skip = 0,
    int take = 40,
  }) async {
    expect(take, 100);
    expect(accountId, '11111111-2222-3333-4444-555555555555');
    return pages[calls++];
  }
}

Future<AccountFinancialSummary> summary(SummaryClient client) =>
    loadAccountFinancialSummary(
      client: client,
      serverUrl: 'https://ghostfol.io',
      jwt: 'token',
      accountId: accountId,
    );

void main() {
  test('dividend reconciliation accepts floating-point noise', () {
    expect(dividendsReconcile(0.1 + 0.2, 0.3), isTrue);
  });

  test('dividend reconciliation rejects monetary differences', () {
    expect(dividendsReconcile(100.00, 100.01), isFalse);
    expect(dividendsReconcile(100.00, 99.99), isFalse);
  });

  test('dividend reconciliation rejects non-finite values', () {
    expect(dividendsReconcile(double.nan, 100), isFalse);
    expect(dividendsReconcile(double.infinity, 100), isFalse);
  });

  test('separates trading fees and dividend taxes without inferring standalone fees', () async {
    final result = await summary(
      SummaryClient([
        ActivityBatch(
          activities: [
            activity('buy', 'BUY', fee: 2),
            activity('sell', 'SELL', fee: 3),
            activity('charge', 'FEE', value: -7, fee: 7),
            activity('dividend', 'DIVIDEND', tax: 4, value: 20),
            activity('draft', 'DIVIDEND', tax: 100, draft: true),
          ],
          count: 5,
        ),
      ]),
    );
    expect(result.tradingFees, 5);
    expect(result.dividendGross, 20);
    expect(result.dividendTaxes, 4);
  });

  test('missing dividend tax is not zero', () async {
    final result = await summary(
      SummaryClient([
        ActivityBatch(activities: [activity('d', 'DIVIDEND')], count: 1),
      ]),
    );
    expect(result.dividendTaxes, isNull);
  });

  test('explicit zero dividend tax remains visible', () async {
    final result = await summary(
      SummaryClient([
        ActivityBatch(
          activities: [activity('d', 'DIVIDEND', tax: 0)],
          count: 1,
        ),
      ]),
    );
    expect(result.dividendTaxes, 0);
  });

  test('missing gross dividend value blocks reconciliation', () async {
    final result = await summary(
      SummaryClient([
        ActivityBatch(
          activities: [activity('d', 'DIVIDEND', tax: 2)],
          count: 1,
        ),
      ]),
    );
    expect(result.dividendGross, isNull);
    expect(result.dividendTaxes, 2);
  });

  test('duplicate pages are rejected', () async {
    final client = SummaryClient([
      ActivityBatch(activities: [activity('a', 'BUY', fee: 1)], count: 2),
      ActivityBatch(activities: [activity('a', 'BUY', fee: 1)], count: 2),
    ]);
    await expectLater(summary(client), throwsFormatException);
  });

  test('short or changing snapshots are rejected', () async {
    final client = SummaryClient([
      ActivityBatch(activities: [activity('a', 'BUY', fee: 1)], count: 2),
      const ActivityBatch(activities: [], count: 2),
    ]);
    await expectLater(summary(client), throwsFormatException);
  });
}
