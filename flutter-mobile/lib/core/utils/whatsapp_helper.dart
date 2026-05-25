import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  static final _nonDigit = RegExp(r'\D');

  /// Türk numaralarını wa.me formatına çevirir.
  /// - `05XXXXXXXXX` veya `5XXXXXXXXX` → `905XXXXXXXXX`
  /// - `90XXXXXXXXXX` → aynen
  /// - `+90...` → `90...`
  /// Geçersizse `null` döner.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('90') && digits.length == 12) {
      return digits;
    }
    if (digits.startsWith('0') && digits.length == 11) {
      return '9$digits';
    }
    if (digits.length == 10 && digits.startsWith('5')) {
      return '90$digits';
    }
    return null;
  }

  static Uri? buildUri(String? rawPhone, String message) {
    final norm = normalize(rawPhone);
    if (norm == null) return null;
    return Uri.parse('https://wa.me/$norm?text=${Uri.encodeComponent(message)}');
  }

  /// WhatsApp linkini açar. Başarılı olursa `true`.
  static Future<bool> open(String? rawPhone, String message) async {
    final uri = buildUri(rawPhone, message);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
