import 'package:dio/dio.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/core/errors/error_handler.dart';
import 'package:koyden_sehire/core/storage/secure_storage_service.dart';

class ApiClient {
  final SecureStorageService _storage;
  late final Dio _dio;

  ApiClient(this._storage, {required void Function() onUnauthorized}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.apiConnectTimeout,
        receiveTimeout: AppConstants.apiReceiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_storage, _dio, onUnauthorized));
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic) parse,
  }) =>
      _request('GET', path, query: query, parse: parse);

  Future<T> post<T>(
    String path, {
    dynamic data,
    required T Function(dynamic) parse,
  }) =>
      _request('POST', path, data: data, parse: parse);

  Future<T> put<T>(
    String path, {
    dynamic data,
    required T Function(dynamic) parse,
  }) =>
      _request('PUT', path, data: data, parse: parse);

  Future<T> patch<T>(
    String path, {
    dynamic data,
    required T Function(dynamic) parse,
  }) =>
      _request('PATCH', path, data: data, parse: parse);

  Future<T> delete<T>(
    String path, {
    dynamic data,
    required T Function(dynamic) parse,
  }) =>
      _request('DELETE', path, data: data, parse: parse);

  Future<T> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    dynamic data,
    required T Function(dynamic) parse,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: data,
        options: Options(method: method),
      );
      return parse(response.data);
    } on DioException catch (e) {
      throw mapDioError(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(message: 'Beklenmeyen bir hata oluştu: $e');
    }
  }
}

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  // The same Dio instance is used for the refresh call so it shares base
  // options (baseUrl, timeouts), but we send the request without going
  // through this interceptor to prevent an infinite retry loop.
  final Dio _dio;
  final void Function() _onUnauthorized;

  _AuthInterceptor(this._storage, this._dio, this._onUnauthorized);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Already a refresh call — don't retry again.
    if (err.requestOptions.path.endsWith(ApiEndpoints.authRefresh)) {
      await _storage.clearAll();
      _onUnauthorized();
      handler.next(err);
      return;
    }

    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearAll();
      _onUnauthorized();
      handler.next(err);
      return;
    }

    try {
      // Send the refresh request directly (no interceptors) to avoid a loop.
      final refreshResponse = await _dio.fetch<Map<String, dynamic>>(
        RequestOptions(
          path: ApiEndpoints.authRefresh,
          method: 'POST',
          data: {'refresh_token': refreshToken},
          baseUrl: _dio.options.baseUrl,
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      );

      final data = (refreshResponse.data?['data'] as Map?)
          ?.cast<String, dynamic>();
      final newAccessToken = data?['access_token']?.toString() ?? '';
      final newRefreshToken = data?['refresh_token']?.toString() ?? '';

      if (newAccessToken.isEmpty) {
        await _storage.clearAll();
        _onUnauthorized();
        handler.next(err);
        return;
      }

      await _storage.saveToken(newAccessToken);
      if (newRefreshToken.isNotEmpty) {
        await _storage.saveRefreshToken(newRefreshToken);
      }

      // Retry the original request with the new access token.
      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await _storage.clearAll();
      _onUnauthorized();
      handler.next(err);
    }
  }
}
