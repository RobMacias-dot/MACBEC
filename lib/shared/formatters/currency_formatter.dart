import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter({String locale = 'es_MX'})
      : _formatter = NumberFormat.currency(locale: locale, symbol: r'$');

  final NumberFormat _formatter;

  String format(num value) => _formatter.format(value);
}
