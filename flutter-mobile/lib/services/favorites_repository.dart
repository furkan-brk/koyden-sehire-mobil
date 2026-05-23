import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/product_model.dart';

class FavoritesRepository {
  final ApiClient _api;
  FavoritesRepository(this._api);

  Future<List<ProductModel>> list() {
    return _api.get(
      ApiEndpoints.customerFavorites,
      parse: (env) {
        final list = ((env as Map)['data'] as List?) ?? const [];
        return list
            .whereType<Map>()
            .map((m) => ProductModel.fromJson(m.cast<String, dynamic>()))
            .toList();
      },
    );
  }

  Future<void> add(String productId) {
    return _api.post(
      ApiEndpoints.customerFavoriteById(productId),
      parse: (_) {},
    );
  }

  Future<void> remove(String productId) {
    return _api.delete(
      ApiEndpoints.customerFavoriteById(productId),
      parse: (_) {},
    );
  }
}
