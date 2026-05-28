import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/storage/secure_storage_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/models/auth/login_request.dart';
import 'package:koyden_sehire/models/auth/login_response.dart';
import 'package:koyden_sehire/models/auth/user_model.dart';
import 'package:koyden_sehire/services/auth_repository.dart';
import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/core/services/push_notification_service.dart';
import 'package:koyden_sehire/services/push_token_repository.dart';

// --- mocks ---

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

/// Stub PushTokenRepository needed by PushNotificationService constructor.
class MockPushTokenRepository extends Mock implements PushTokenRepository {}

/// A concrete no-op subclass — mocktail cannot mock GetxService subclasses
/// because they have internal callbacks that must be non-null.
class _FakePushNotificationService extends PushNotificationService {
  _FakePushNotificationService() : super(MockPushTokenRepository());

  @override
  Future<void> onLogin() async {}

  @override
  Future<void> onLogout() async {}
}

// --- helpers ---

LoginResponse _makeFarmerResponse() => const LoginResponse(
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      user: UserModel(
        id: 'u-001',
        fullName: 'Test Çiftçi',
        phone: '05321234567',
        role: 'farmer',
        status: 'active',
      ),
    );

LoginResponse _makeCustomerResponse() => const LoginResponse(
      accessToken: 'test-access-token-cust',
      refreshToken: 'test-refresh-token-cust',
      user: UserModel(
        id: 'u-002',
        fullName: 'Test Müşteri',
        phone: '05321234568',
        role: 'customer',
        status: 'active',
      ),
    );

void main() {
  setUpAll(() {
    // mocktail requires fallback values for any custom type used with any().
    registerFallbackValue(const LoginRequest(phone: '05300000000', password: 'fallback'));
  });

  late MockAuthRepository mockRepo;
  late MockSecureStorageService mockStorage;
  late AuthService authService;

  setUp(() {
    Get.reset();

    mockRepo = MockAuthRepository();
    mockStorage = MockSecureStorageService();

    // Stub storage methods used by _applyLoginResponse
    when(() => mockStorage.saveToken(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveRefreshToken(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveUserInfo(
          id: any(named: 'id'),
          role: any(named: 'role'),
          status: any(named: 'status'),
          displayName: any(named: 'displayName'),
        )).thenAnswer((_) async {});

    // Register services in GetX — push service must be a real GetxService subclass.
    Get.put<AuthRepository>(mockRepo);
    Get.put<PushNotificationService>(_FakePushNotificationService());

    authService = AuthService(mockStorage);
    Get.put<AuthService>(authService);
  });

  tearDown(() => Get.reset());

  group('AuthService.login()', () {
    test('success - farmer - sets farmerActive status', () async {
      when(() => mockRepo.login(any())).thenAnswer((_) async => _makeFarmerResponse());

      await authService.login(phone: '05321234567', password: 'securepassword');

      expect(authService.status.value, AuthStatus.farmerActive);
      expect(authService.errorMessage.value, isNull);
      expect(authService.userId.value, 'u-001');
    });

    test('success - customer - sets customerActive status', () async {
      when(() => mockRepo.login(any())).thenAnswer((_) async => _makeCustomerResponse());

      await authService.login(phone: '05321234568', password: 'securepassword');

      expect(authService.status.value, AuthStatus.customerActive);
      expect(authService.errorMessage.value, isNull);
    });

    test('wrong credentials - sets errorMessage, status unchanged', () async {
      const initialStatus = AuthStatus.unknown;

      when(() => mockRepo.login(any())).thenThrow(
        const AppException(
          message: 'Telefon numarası veya şifre hatalı',
          code: 'INVALID_CREDENTIALS',
          statusCode: 401,
        ),
      );

      await authService.login(phone: '05321234567', password: 'wrong-password');

      expect(authService.errorMessage.value, isNotNull);
      expect(authService.errorMessage.value, contains('şifre hatalı'));
      expect(authService.status.value, initialStatus);
      expect(authService.isSubmitting.value, isFalse);
    });

    test('network error - sets generic error message', () async {
      when(() => mockRepo.login(any())).thenThrow(Exception('network failure'));

      await authService.login(phone: '05321234567', password: 'anything');

      expect(authService.errorMessage.value, isNotNull);
      expect(authService.isSubmitting.value, isFalse);
    });
  });
}
