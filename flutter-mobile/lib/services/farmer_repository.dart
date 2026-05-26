import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/shared/models/pagination_model.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/models/farmer_model.dart';

class FarmerRepository {
  final ApiClient _api;
  FarmerRepository(this._api);

  Future<Paginated<FarmerSummary>> list({
    int page = 1,
    int limit = 20,
    String? city,
    String? district,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (city != null && city.isNotEmpty) 'city': city,
      if (district != null && district.isNotEmpty) 'district': district,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    return _api.get(
      ApiEndpoints.farmers,
      query: query,
      parse: (env) {
        final map = (env as Map);
        final list = (map['data'] as List?) ?? const [];
        final items = list
            .whereType<Map>()
            .map((m) => FarmerSummary.fromJson(m.cast<String, dynamic>()))
            .toList();
        final pag = (map['pagination'] as Map?)?.cast<String, dynamic>();
        return Paginated(
          items: items,
          pagination: pag == null
              ? Pagination(
                  page: page,
                  limit: limit,
                  total: items.length,
                  totalPages: 1,
                )
              : Pagination.fromJson(pag),
        );
      },
    );
  }

  Future<FarmerProfile> getById(String id) {
    return _api.get(
      ApiEndpoints.farmerById(id),
      parse: (env) {
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        return FarmerProfile.fromJson(data);
      },
    );
  }

  Future<List<ProductModel>> getProducts(String farmerId) {
    return _api.get(
      ApiEndpoints.farmerProducts(farmerId),
      parse: (env) {
        final list = ((env as Map)['data'] as List?) ?? const [];
        return list
            .whereType<Map>()
            .map((m) => ProductModel.fromJson(m.cast<String, dynamic>()))
            .toList();
      },
    );
  }
}
