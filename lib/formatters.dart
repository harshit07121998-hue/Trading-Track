import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final NumberFormat _inrWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final DateFormat _shortDate = DateFormat('dd MMM yyyy');

String formatMoney(double value, {bool whole = false}) {
  final f = whole ? _inrWhole : _inr;
  return f.format(value);
}

String formatSignedMoney(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${formatMoney(value)}';
}

String formatPct(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String formatDate(DateTime d) => _shortDate.format(d);

String formatQty(double q) {
  if (q == q.roundToDouble()) return q.toStringAsFixed(0);
  return q.toString();
}
