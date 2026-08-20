import 'dart:math' as math;

// XIRR (money-weighted annualised return) calculator using Newton-Raphson.
// Convention: outflows (buys) are negative, inflows (sells / current
// market value) are positive.

class CashFlow {
  final DateTime date;
  final double amount;
  CashFlow(this.date, this.amount);
}

class XirrCalculator {
  static double _npv(List<CashFlow> flows, double rate, DateTime t0) {
    double total = 0;
    for (final f in flows) {
      final years = f.date.difference(t0).inDays / 365.0;
      total += f.amount / math.pow(1 + rate, years);
    }
    return total;
  }

  /// Returns XIRR as a percentage (e.g. 24.18 for 24.18%), or null if it
  /// cannot be solved (e.g. fewer than 2 cash flows, or no sign change).
  static double? calculate(List<CashFlow> flows) {
    if (flows.length < 2) return null;
    final sorted = [...flows]..sort((a, b) => a.date.compareTo(b.date));
    final hasPositive = sorted.any((f) => f.amount > 0);
    final hasNegative = sorted.any((f) => f.amount < 0);
    if (!hasPositive || !hasNegative) return null;

    final t0 = sorted.first.date;
    double rate = 0.1;
    for (int i = 0; i < 100; i++) {
      final npv = _npv(sorted, rate, t0);
      final npvUp = _npv(sorted, rate + 1e-6, t0);
      final derivative = (npvUp - npv) / 1e-6;
      if (derivative.abs() < 1e-12 || derivative.isNaN) break;
      final newRate = rate - npv / derivative;
      if ((newRate - rate).abs() < 1e-7) {
        rate = newRate;
        break;
      }
      rate = newRate;
      if (rate <= -0.999999) rate = -0.999999;
      if (rate.isNaN || rate.isInfinite) return null;
    }
    if (rate.isNaN || rate.isInfinite) return null;
    return rate * 100;
  }
}
