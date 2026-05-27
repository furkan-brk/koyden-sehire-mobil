import 'package:dio/dio.dart';

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

  /// Uploads a product image via multipart POST.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadProductImage(
    List<int> bytes, {
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) {
    return _api.post(
      ApiEndpoints.uploadProductImage,
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
}
