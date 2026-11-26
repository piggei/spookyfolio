import 'portfolio_client.dart';

/// Server-provided Portfolio Evolution, not contributions, profit, ROI or PnL.
/// Currency comes from the existing profile; this endpoint has no currency field.
class PortfolioEvolution {
  PortfolioEvolution.fromHistory(
    PortfolioHistory history, {
    required this.baseCurrency,
  }) : points = List.unmodifiable(
         history.points.map(
           (point) => PortfolioEvolutionPoint(
             date: point.date,
             investedCapital: point.totalInvestmentValueWithCurrencyEffect,
             portfolioValue: point.valueWithCurrencyEffect,
             normalizedPortfolioValue: point.valueInPercentage,
           ),
         ),
       ),
       dateOfFirstActivity = history.dateOfFirstActivity,
       hasErrors = history.hasErrors;

  final String? baseCurrency;
  final List<PortfolioEvolutionPoint> points;
  final DateTime? dateOfFirstActivity;
  final bool hasErrors;
  bool get hasCompleteMonetarySeries =>
      points.isNotEmpty && points.every((point) => point.hasMonetaryComparison);
}

class PortfolioEvolutionPoint {
  const PortfolioEvolutionPoint({
    required this.date,
    this.investedCapital,
    this.portfolioValue,
    this.normalizedPortfolioValue,
  });
  final DateTime date;
  final double? investedCapital;
  final double? portfolioValue;

  /// Restricted/Zen series, a fraction of a reference value, never money.
  final double? normalizedPortfolioValue;
  bool get hasMonetaryComparison =>
      investedCapital != null && portfolioValue != null;
}
