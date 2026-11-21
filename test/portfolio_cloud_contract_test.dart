import 'package:flutter_test/flutter_test.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test('Cloud Basic performance retains visible return history', () {
    final history = PortfolioHistory.fromJson({
      'performance': {
        'currentValueInBaseCurrency': 318.70,
        'netPerformanceWithCurrencyEffect': -21.30,
        'netPerformance': null,
      },
      'chart': [
        {
          'date': '2026-11-20',
          'value': null,
          'netPerformanceInPercentageWithCurrencyEffect': 0,
        },
        {
          'date': '2026-11-21',
          'value': null,
          'netPerformanceInPercentageWithCurrencyEffect': -0.0626,
        },
      ],
    });
    expect(history.portfolioValue, 318.70);
    expect(history.changeWithCurrencyEffect, -21.30);
    expect(history.points, hasLength(2));
    expect(history.points.last.value, isNull);
    expect(history.points.last.returnWithCurrencyEffect, -0.0626);
  });

  test('Empty chart and redacted performance remain unavailable', () {
    final history = PortfolioHistory.fromJson({
      'performance': {
        'currentValueInBaseCurrency': null,
        'netPerformanceWithCurrencyEffect': null,
      },
      'chart': [],
    });
    expect(history.points, isEmpty);
    expect(history.portfolioValue, isNull);
    expect(history.changeWithCurrencyEffect, isNull);
  });
}
