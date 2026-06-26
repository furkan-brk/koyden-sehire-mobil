import 'dart:io';

import 'package:dio/dio.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/core/errors/error_handler.dart';
import 'package:koyden_sehire/models/application_model.dart';

class ApplicationRepository {
  final ApiClient _api;
  ApplicationRepository(this._api);

  Future<InviteInfo> validateInvite(String code) {
    return _api.get(
      ApiEndpoints.inviteValidate,
      query: {'code': code.trim().toUpperCase()},
      parse: (env) {
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        return InviteInfo.fromJson(data);
      },
    );
  }

  /// Returns (uploadUrl, key).
  Future<({String uploadUrl, String key})> getVideoPresignedUrl({
    required String phone,
    required String inviteCode,
    String contentType = 'video/mp4',
  }) {
    return _api.post(
      ApiEndpoints.applicationVideoPresignedUrl,
      data: {
        'phone': phone,
        'invite_code': inviteCode,
        'content_type': contentType,
      },
      parse: (env) {
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        return (
          uploadUrl: AppConstants.formatDevUrl(data['upload_url']?.toString() ?? ''),
          key: data['key']?.toString() ?? '',
        );
      },
    );
  }

  /// PUTs the file directly to R2 using the presigned URL.
  Future<void> uploadVideoToPresigned({
    required String uploadUrl,
    required File file,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final dio = Dio();
    try {
      final length = await file.length();
      final stream = file.openRead();
      await dio.put(
        uploadUrl,
        data: stream,
        onSendProgress: onProgress,
        options: Options(
          headers: {
            HttpHeaders.contentTypeHeader: contentType,
            HttpHeaders.contentLengthHeader: length,
          },
        ),
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> submit({
    required String inviteCode,
    required ApplicationFormData data,
  }) async {
    await _api.post(
      ApiEndpoints.farmerApplications,
      data: data.toJson(inviteCode: inviteCode),
      parse: (_) => null,
    );
  }
}
