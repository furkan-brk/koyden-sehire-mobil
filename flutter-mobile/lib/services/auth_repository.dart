import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/auth/login_request.dart';
import 'package:koyden_sehire/models/auth/login_response.dart';
import 'package:koyden_sehire/models/auth/register_customer_request.dart';

class AuthRepository {
  final ApiClient _api;
  AuthRepository(this._api);

  Future<LoginResponse> login(LoginRequest req) {
    return _api.post(
      ApiEndpoints.login,
      data: req.toJson(),
      parse: (env) {
        final data = (env as Map)['data'] as Map?;
        return LoginResponse.fromJson(
          (data ?? const {}).cast<String, dynamic>(),
        );
      },
    );
  }

  /// Registers a new customer. Requires that the OTP for [req.phone]
  /// has already been verified (otp_verified key still alive in Redis).
  Future<LoginResponse> registerCustomer(RegisterCustomerRequest req) {
    return _api.post(
      ApiEndpoints.registerCustomer,
      data: req.toJson(),
      parse: (env) {
        final data = (env as Map)['data'] as Map?;
        return LoginResponse.fromJson(
          (data ?? const {}).cast<String, dynamic>(),
        );
      },
    );
  }

  /// Asks the backend to send an SMS OTP to [phone].
  /// Same endpoint is used for app-wide phone verification.
  Future<void> sendOtp(String phone) async {
    await _api.post<void>(
      ApiEndpoints.otpSend,
      data: {'phone': phone},
      parse: (_) {},
    );
  }

  /// Verifies an OTP [code] for [phone]. On success the backend marks the
  /// phone as verified for ~30 minutes so it can be consumed by register.
  Future<void> verifyOtp(String phone, String code) async {
    await _api.post<void>(
      ApiEndpoints.otpVerify,
      data: {'phone': phone, 'code': code},
      parse: (_) {},
    );
  }

  /// Triggers a password-reset OTP to be sent to [phone]. The backend
  /// must respond identically regardless of whether the number is on file
  /// to avoid leaking account existence.
  Future<void> forgotPassword(String phone) async {
    await _api.post<void>(
      ApiEndpoints.forgotPassword,
      data: {'phone': phone},
      parse: (_) {},
    );
  }

  /// Completes the password-reset flow with the OTP delivered to [phone].
  Future<void> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post<void>(
      ApiEndpoints.resetPassword,
      data: {
        'phone': phone,
        'otp': otp,
        'new_password': newPassword,
      },
      parse: (_) {},
    );
  }
}
