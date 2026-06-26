import 'package:dio/dio.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/product_form_config.dart';
import 'package:koyden_sehire/models/farmer_product_model.dart';

class FarmerProductRepository {
  final ApiClient _api;
  FarmerProductRepository(this._api);

  Future<List<FarmerProductModel>> list({String? status}) {
    return _api.get(
      ApiEndpoints.farmerProducts2,
      query: status == null ? null : {'status': status},
      parse: (env) {
        final list = ((env as Map)['data'] as List?) ?? const [];
        return list
            .whereType<Map>()
            .map(
              (m) => FarmerProductModel.fromJson(m.cast<String, dynamic>()),
            )
            .toList();
      },
    );
  }

  Future<FarmerProductModel> getById(String id) {
    return _api.get(
      ApiEndpoints.farmerProduct(id),
      parse: (env) {
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        return FarmerProductModel.fromJson(data);
      },
    );
  }

  Future<void> create(ProductFormData data) async {
    await _api.post(
      ApiEndpoints.farmerProducts2,
      data: data.toJson(),
      parse: (_) => null,
    );
  }

  Future<void> update(String id, ProductFormData data) async {
    await _api.put(
      ApiEndpoints.farmerProduct(id),
      data: data.toJson(),
      parse: (_) => null,
    );
  }

  Future<void> setStockStatus(String id, String stockStatus) async {
    await _api.patch(
      ApiEndpoints.farmerProductStatus(id),
      data: {'stock_status': stockStatus},
      parse: (_) => null,
    );
  }

  /// Updates a product's listing status (e.g. `active`, `passive`).
  Future<void> setStatus(String id, String status) async {
    await _api.patch(
      ApiEndpoints.farmerProductStatus(id),
      data: {'status': status},
      parse: (_) => null,
    );
  }

  /// Deletes the farmer's product.
  Future<void> delete(String id) async {
    await _api.delete(
      ApiEndpoints.farmerProduct(id),
      parse: (_) => null,
    );
  }


  /// Uploads a profile image via multipart POST.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadProfileImage(
    List<int> bytes, {
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) {
    return _api.post(
      ApiEndpoints.uploadProfileImage,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      }),
      parse: (env) {
        // Backend uploads handler always returns `{success, data: {url: "..."}}`
        // (see backend/internal/uploads/dto.go::UploadImageResponse).
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        return data['url']?.toString() ?? '';
      },
    );
  }

  /// Uploads a product image via S3 presigned URL.
  /// First obtains a presigned URL, then uploads the file directly to S3.
  /// Returns the key and public URL.
  Future<UploadResult> uploadProductImage(
    String productId,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    // 1. Get presigned URL
    final Map<String, dynamic> presignData = await _api.post(
      ApiEndpoints.uploadProductImagePresign,
      data: {
        'product_id': productId,
        'file_size': bytes.length,
        'content_type': contentType,
      },
      parse: (env) {
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        return data;
      },
    );

    final uploadUrl = AppConstants.formatDevUrl(presignData['upload_url']?.toString() ?? '');
    final key = presignData['key']?.toString() ?? '';
    final publicUrl = AppConstants.formatDevUrl(presignData['url']?.toString() ?? '');

    if (uploadUrl.isEmpty || key.isEmpty) {
      throw Exception('Presigned URL alınamadı');
    }

    final Map<String, dynamic> headersMap = (presignData['headers'] as Map?)?.cast<String, dynamic>() ?? {};

    // 2. Direct PUT to S3 using a clean Dio client to prevent JWT headers insertion
    final response = await Dio().put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: headersMap.isNotEmpty
            ? headersMap
            : {
                Headers.contentTypeHeader: contentType,
              },
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Görsel sunucuya yüklenemedi: ${response.statusCode}');
    }

    return UploadResult(url: publicUrl, key: key);
  }

  /// Completes a product draft and updates its status to 'pending'
  Future<void> complete(
    String id,
    ProductFormData data,
    List<String> imageKeys,
  ) async {
    await _api.post(
      ApiEndpoints.farmerProductComplete(id),
      data: {
        ...data.toJson(),
        'image_keys': imageKeys,
      },
      parse: (_) => null,
    );
  }
}

class UploadResult {
  final String url;
  final String key;
  UploadResult({required this.url, required this.key});
}

