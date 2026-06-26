import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/core/errors/app_exception.dart';

/// Maps Dio errors and the backend response envelope into [AppException].
/// Backend error shape: `{success:false, error:{code, message}}`.
AppException mapDioError(Object error) {
  if (error is AppException) return error;
  if (error is! DioException) {
    return const AppException(message: 'Beklenmeyen bir hata oluştu');
  }

  final type = error.type;
  if (type == DioExceptionType.connectionError ||
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.receiveTimeout ||
      type == DioExceptionType.sendTimeout) {
    if (kDebugMode) {
      return NetworkException(
        message: 'Sunucuya ulaşılamıyor (${AppConstants.baseUrl}). '
            'Backend çalışıyor mu? BASE_URL doğru mu?',
      );
    }
    return const NetworkException();
  }

  final response = error.response;
  final status = response?.statusCode;
  final data = response?.data;

  String? backendCode;
  String? backendMessage;
  if (data is Map && data['error'] is Map) {
    final err = data['error'] as Map;
    backendCode = err['code']?.toString();
    backendMessage = err['message']?.toString();
  }

  switch (status) {
    case 400:
      return ValidationException(
        message: backendMessage ?? 'Geçersiz istek',
        code: backendCode,
      );
    case 401:
      return AuthException(
        message: backendMessage ?? 'Giriş yapmanız gerekiyor',
        code: backendCode ?? 'UNAUTHORIZED',
      );
    case 403:
      return ForbiddenException(
        message: backendMessage ?? 'Bu işlem için yetkiniz yok',
      );
    case 404:
      return NotFoundException(message: backendMessage ?? 'Bulunamadı');
    case 409:
      return ValidationException(
        message: backendMessage ?? 'Çakışma oluştu',
        code: backendCode ?? 'CONFLICT',
      );
    case 429:
      final retryAfter = response?.headers.value('retry-after');
      return RateLimitException(
        message: backendMessage ?? 'Çok fazla istek. Lütfen bekleyin.',
        retryAfterSeconds: int.tryParse(retryAfter ?? ''),
      );
    case 500:
    case 502:
    case 503:
      return ServerException(
        message: backendMessage ?? 'Sunucu hatası. Lütfen tekrar deneyin.',
      );
  }

  return AppException(
    message: backendMessage ?? 'Bir hata oluştu, tekrar deneyin',
    code: backendCode,
    statusCode: status,
  );
}
