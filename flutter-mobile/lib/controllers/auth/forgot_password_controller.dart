import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/services/auth_repository.dart';

/// Drives the two-step "forgot password" flow:
///   1. [requestReset] → backend sends a 6-digit OTP via SMS
///   2. [confirmReset] → user submits OTP + new password
class ForgotPasswordController extends GetxController {
  final AuthRepository _repo;
  ForgotPasswordController(this._repo);

  final RxBool isSending = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString infoMessage = RxnString();
  final RxBool otpSent = false.obs;
  final RxBool passwordReset = false.obs;
  final RxnString phone = RxnString();

  Future<bool> requestReset(String phoneNumber) async {
    isSending.value = true;
    errorMessage.value = null;
    infoMessage.value = null;
    try {
      await _repo.forgotPassword(phoneNumber);
      phone.value = phoneNumber;
      otpSent.value = true;
      infoMessage.value =
          'Bu numara sistemde kayıtlıysa kısa süre içinde bir SMS alacaksınız.';
      isSending.value = false;
      return true;
    } on AppException catch (e) {
      String msg = e.message;
      if (e.code == 'INVALID_PHONE') msg = 'Geçersiz telefon numarası';
      if (e.code == 'RATE_LIMITED' || e.code == 'COOLDOWN_ACTIVE') {
        msg = 'Çok sık deneme. Lütfen biraz bekleyin.';
      }
      errorMessage.value = msg;
      isSending.value = false;
      return false;
    } catch (_) {
      errorMessage.value = 'İstek gönderilemedi. Tekrar deneyin.';
      isSending.value = false;
      return false;
    }
  }

  Future<bool> confirmReset({
    required String phoneNumber,
    required String otp,
    required String newPassword,
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      await _repo.resetPassword(
        phone: phoneNumber,
        otp: otp,
        newPassword: newPassword,
      );
      passwordReset.value = true;
      isSubmitting.value = false;
      return true;
    } on AppException catch (e) {
      String msg = e.message;
      if (e.code == 'INVALID_CODE') msg = 'Kod hatalı, tekrar deneyin';
      if (e.code == 'OTP_EXPIRED') {
        msg = 'Kodun süresi doldu, yeni kod isteyin';
      }
      if (e.code == 'MAX_ATTEMPTS') {
        msg = 'Çok fazla yanlış deneme. Yeni kod isteyin.';
      }
      if (e.code == 'WEAK_PASSWORD') {
        msg = 'Şifre çok zayıf. En az 8 karakter kullanın.';
      }
      errorMessage.value = msg;
      isSubmitting.value = false;
      return false;
    } catch (_) {
      errorMessage.value = 'Şifre güncellenemedi. Tekrar deneyin.';
      isSubmitting.value = false;
      return false;
    }
  }

  void reset() {
    isSending.value = false;
    isSubmitting.value = false;
    errorMessage.value = null;
    infoMessage.value = null;
    otpSent.value = false;
    passwordReset.value = false;
    phone.value = null;
  }
}
