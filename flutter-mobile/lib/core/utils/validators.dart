import 'package:koyden_sehire/core/utils/phone_formatter.dart';

class Validators {
  static String? required(String? v, {String field = 'Bu alan'}) {
    if (v == null || v.trim().isEmpty) return '$field zorunludur';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Telefon numarası zorunludur';
    if (!PhoneFormatter.isValid(v)) {
      return 'Geçerli bir telefon numarası girin (05XXXXXXXXX)';
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Şifre zorunludur';
    if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() other) {
    return (v) {
      if (v == null || v.isEmpty) return 'Şifreyi tekrar girin';
      if (v != other()) return 'Şifreler eşleşmiyor';
      return null;
    };
  }

  static String? email(String? v) {
    if (v == null || v.isEmpty) return null; // optional
    final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]+$').hasMatch(v.trim());
    return ok ? null : 'Geçerli bir e-posta girin';
  }

  static String? inviteCode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Davet kodu girin';
    // Backend tam 6 karakterlik sonek (veya KYS-FOUNDER) kabul ediyor —
    // invites/service.go isValidCodeFormat ile aynı kural.
    final ok = RegExp(r'^KYS-([A-Z0-9]{6}|FOUNDER)$')
        .hasMatch(v.trim().toUpperCase());
    return ok ? null : 'Davet kodu KYS-XXXXXX biçiminde olmalı';
  }

  static String? positiveNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Bu alan zorunludur';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Geçerli bir sayı girin';
    return null;
  }
}
