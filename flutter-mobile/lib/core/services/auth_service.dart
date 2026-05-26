import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/core/services/push_notification_service.dart';
import 'package:koyden_sehire/services/auth_repository.dart';
import 'package:koyden_sehire/models/auth/login_request.dart';
import 'package:koyden_sehire/models/auth/login_response.dart';
import 'package:koyden_sehire/models/auth/register_customer_request.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/core/storage/secure_storage_service.dart';

/// Global authentication state, persisted via [SecureStorageService].
///
/// Replaces the previous `authProvider` (Riverpod StateNotifier).
class AuthService extends GetxService {
  final SecureStorageService _storage;
  AuthService(this._storage);

  final Rx<AuthStatus> status = AuthStatus.unknown.obs;
  final RxnString userId = RxnString();
  final RxnString displayName = RxnString();
  final RxnString errorMessage = RxnString();
  final RxBool isSubmitting = false.obs;

  /// Üretici pazar modunda mı? (Kalıcı değil — uygulama kapanınca sıfırlanır)
  final RxBool isBrowsingAsCustomer = false.obs;

  void enterCustomerMode() => isBrowsingAsCustomer.value = true;
  void exitCustomerMode() => isBrowsingAsCustomer.value = false;

  AuthRepository get _repo => Get.find<AuthRepository>();

  /// Called by the API client when a 401 is received.
  Future<void> handleUnauthorized() async {
    await _storage.clearAll();
    _resetTo(AuthStatus.loggedOut);
  }

  void _resetTo(AuthStatus s, {String? id, String? name, String? error}) {
    status.value = s;
    userId.value = id;
    displayName.value = name;
    errorMessage.value = error;
    isSubmitting.value = false;
  }

  /// Read persisted state and decide where the splash should land.
  Future<void> bootstrap() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      _resetTo(AuthStatus.loggedOut);
      return;
    }
    final role = await _storage.getUserRole();
    final st = await _storage.getUserStatus();
    final id = await _storage.getUserId();
    final name = await _storage.getDisplayName();

    if (role == 'admin') {
      _resetTo(AuthStatus.admin, id: id, name: name);
    } else if (role == 'farmer' && st == 'active') {
      _resetTo(AuthStatus.farmerActive, id: id, name: name);
    } else if (role == 'farmer' && st == 'suspended') {
      _resetTo(
        AuthStatus.farmerSuspended,
        error: 'Hesabınız askıya alınmıştır',
      );
    } else if (role == 'customer' && st == 'active') {
      _resetTo(AuthStatus.customerActive, id: id, name: name);
    } else {
      await _storage.clearAll();
      _resetTo(AuthStatus.loggedOut);
    }
  }

  Future<void> login({required String phone, required String password}) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final res = await _repo.login(
        LoginRequest(phone: phone, password: password),
      );
      await _applyLoginResponse(res);
    } on AppException catch (e) {
      errorMessage.value = _mapAuthError(e);
    } catch (_) {
      errorMessage.value = 'Bir hata oluştu, tekrar deneyin';
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Requests an OTP for customer registration. Backend doesn't distinguish
  /// the purpose at the API level — the same /otp/send endpoint is used.
  Future<bool> requestRegisterOtp(String phone) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      await _repo.sendOtp(phone);
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'OTP gönderilemedi, tekrar deneyin';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Verifies the OTP. On success the backend keeps an `otp_verified` marker
  /// alive for ~30 minutes which [registerCustomer] consumes.
  Future<bool> verifyRegisterOtp(String phone, String code) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      await _repo.verifyOtp(phone, code);
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Kod doğrulanamadı, tekrar deneyin';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Creates a customer account and logs the user in. Must be called within
  /// ~30 minutes of [verifyRegisterOtp] for the same phone.
  Future<bool> registerCustomer({
    required String phone,
    required String fullName,
    required String email,
    required String password,
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final res = await _repo.registerCustomer(
        RegisterCustomerRequest(
          phone: phone,
          fullName: fullName,
          email: email,
          password: password,
        ),
      );
      await _applyLoginResponse(res);
      return true;
    } on AppException catch (e) {
      errorMessage.value = _mapAuthError(e);
      return false;
    } catch (_) {
      errorMessage.value = 'Bir hata oluştu, tekrar deneyin';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Shared post-login: persists token + user info, then sets [status]
  /// to the correct AuthStatus value for the role/account state.
  Future<void> _applyLoginResponse(LoginResponse res) async {
    if (!res.user.isActive) {
      errorMessage.value = 'Hesabınız askıya alınmıştır';
      return;
    }

    await _storage.saveToken(res.accessToken);
    if (res.refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(res.refreshToken);
    }
    await _storage.saveUserInfo(
      id: res.user.id,
      role: res.user.role,
      status: res.user.status,
      displayName: res.user.fullName,
    );

    AuthStatus next;
    if (res.user.isAdmin) {
      next = AuthStatus.admin;
    } else if (res.user.isFarmer && res.user.isActive) {
      next = AuthStatus.farmerActive;
    } else if (res.user.isCustomer && res.user.isActive) {
      next = AuthStatus.customerActive;
    } else {
      next = AuthStatus.loggedOut;
    }

    userId.value = res.user.id;
    displayName.value = res.user.fullName;
    status.value = next;

    // Register FCM token with the backend for the authenticated role.
    try {
      final push = Get.find<PushNotificationService>();
      await push.onLogin();
    } catch (e) {
      debugPrint('[AuthService] push.onLogin() HATA: $e');
    }
  }

  String _mapAuthError(AppException e) {
    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        return 'Telefon numarası veya şifre hatalı';
      case 'ACCOUNT_INACTIVE':
      case 'ACCOUNT_SUSPENDED':
        return 'Hesabınız askıya alınmıştır';
      case 'PHONE_TAKEN':
        return 'Bu telefon numarası zaten kayıtlı';
      case 'EMAIL_TAKEN':
        return 'Bu e-posta zaten kayıtlı';
      case 'OTP_NOT_VERIFIED':
        return 'Telefon doğrulaması gerekli, lütfen önce kodu girin';
      default:
        return e.message;
    }
  }

  Future<void> logout() async {
    // Deregister push token before clearing credentials so the request
    // can still be authenticated.
    try {
      final push = Get.find<PushNotificationService>();
      await push.onLogout();
    } catch (_) {}
    isBrowsingAsCustomer.value = false;
    await _storage.clearAll();
    _resetTo(AuthStatus.loggedOut);
  }

  void clearError() {
    errorMessage.value = null;
  }
}
