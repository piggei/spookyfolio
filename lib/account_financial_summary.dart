import 'activity_models.dart';
import 'portfolio_client.dart';

/// Aggregates only complete account-scoped activity snapshots.
/// Missing financial fields remain unknown; they are never coerced to zero.
class AccountFinancialSummary {
  const AccountFinancialSummary({
    this.tradingFees,
    this.dividendGross,
    this.dividendTaxes,
  });

  final double? tradingFees;
  final double? dividendGross;
  final double? dividendTaxes;
}

bool dividendsReconcile(double accountGross, double activityGross) {
  if (!accountGross.isFinite || !activityGross.isFinite) return false;

  final scale = [
    accountGross.abs(),
    activityGross.abs(),
  ].reduce((a, b) => a > b ? a : b);

  // Allow floating-point accumulation noise, not monetary differences.
  final tolerance = scale * 1e-12 + 1e-10;
  return (accountGross - activityGross).abs() <= tolerance;
}

/// A failed, inconsistent or changing paginated snapshot is not a total.
/// The caller hides this optional enrichment on failure.
Future<AccountFinancialSummary> loadAccountFinancialSummary({
  required PortfolioClient client,
  required String serverUrl,
  required String jwt,
  required String accountId,
}) async {
  const pageSize = 100;
  const maxActivities = 10000;
  final seen = <String>{};
  final items = <PortfolioActivity>[];
  int? expected;
  while (true) {
    final batch = await client.getActivitiesForAccount(
      serverUrl: serverUrl,
      jwt: jwt,
      accountId: accountId,
      skip: items.length,
      take: pageSize,
    );
    expected ??= batch.count;
    if (batch.count != expected ||
        expected > maxActivities ||
        batch.activities.length > pageSize ||
        (batch.activities.isEmpty && items.length < expected) ||
        items.length + batch.activities.length > expected) {
      throw const FormatException('Incomplete account activity snapshot');
    }
    for (final item in batch.activities) {
      if (!seen.add(item.id) ||
          (item.accountId != null && item.accountId != accountId)) {
        throw const FormatException('Inconsistent account activity snapshot');
      }
      items.add(item);
    }
    if (items.length == expected) break;
  }

  double trading = 0;
  double gross = 0;
  double taxes = 0;
  bool hasTrading = false;
  bool hasDividend = false;
  bool tradingKnown = true;
  bool grossKnown = true;
  bool taxesKnown = true;
  for (final activity in items) {
    // Draft activities must never contribute to financial totals.
    if (activity.isDraft) continue;
    switch (activity.type) {
      case 'BUY':
      case 'SELL':
        hasTrading = true;
        if (activity.feeInBaseCurrency == null) {
          tradingKnown = false;
        } else {
          trading += activity.feeInBaseCurrency!;
        }
      case 'DIVIDEND':
        hasDividend = true;
        if (activity.valueInBaseCurrency == null) {
          grossKnown = false;
        } else {
          gross += activity.valueInBaseCurrency!;
        }
        if (activity.taxInBaseCurrency == null) {
          taxesKnown = false;
        } else {
          taxes += activity.taxInBaseCurrency!;
        }
      default:
        break;
    }
  }
  return AccountFinancialSummary(
    tradingFees: tradingKnown && hasTrading ? trading : null,
    dividendGross: grossKnown && hasDividend ? gross : null,
    dividendTaxes: taxesKnown && hasDividend ? taxes : null,
  );
}
