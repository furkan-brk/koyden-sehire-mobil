import 'package:intl/intl.dart';

class AppFormatters {
  static final _currency = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final _date = DateFormat('d MMMM y', 'tr_TR');
  static final _dateTime = DateFormat('d MMMM y, HH:mm', 'tr_TR');

  static String currency(num price) => _currency.format(price);
  static String price(num price, String unit) => '${currency(price)} / $unit';

  static String date(DateTime d) => _date.format(d.toLocal());
  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());

  static String? maybeDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? null : date(parsed);
  }
}
