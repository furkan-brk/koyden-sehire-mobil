import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/admin/admin_application_model.dart';
import 'package:koyden_sehire/models/admin/admin_category_model.dart';
import 'package:koyden_sehire/models/admin/admin_city_density_model.dart';
import 'package:koyden_sehire/models/admin/admin_dashboard_model.dart';
import 'package:koyden_sehire/models/admin/admin_farmer_model.dart';
import 'package:koyden_sehire/models/admin/admin_invite_network_model.dart';
import 'package:koyden_sehire/models/admin/admin_product_model.dart';

class AdminRepository {
  final ApiClient _client;
  AdminRepository(this._client);

  Future<AdminDashboardData> getDashboard() async {
    return _client.get<AdminDashboardData>(
      ApiEndpoints.adminDashboard,
      parse: (env) {
        final data =
            ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        final stats =
            (data['stats'] as Map?)?.cast<String, dynamic>() ?? const {};

        List<ChartPoint> parsePoints(dynamic raw) {
          if (raw is! List) return const [];
          return raw
              .whereType<Map>()
              .map((m) => ChartPoint(
                    name: (m['name'] ?? '').toString(),
                    value: (m['value'] as num?)?.toDouble() ?? 0,
                  ))
              .toList();
        }

        int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;

        return AdminDashboardData(
          stats: DashboardStats(
            totalFarmers: asInt(stats['total_farmers']),
            activeFarmers: asInt(stats['active_farmers']),
            suspendedFarmers: asInt(stats['suspended_farmers']),
            pendingApplications: asInt(stats['pending_applications']),
            todayApplications: asInt(stats['today_applications']),
            pendingProducts: asInt(stats['pending_products']),
            activeProducts: asInt(stats['active_products']),
            totalProducts: asInt(stats['total_products']),
          ),
          applicationsByDay: parsePoints(data['applications_by_day']),
          productsByCategory: parsePoints(data['products_by_category']),
          producersByCity: parsePoints(data['producers_by_city']),
        );
      },
    );
  }

  Future<List<AdminApplication>> getApplications({String? status}) async {
    return _client.get<List<AdminApplication>>(
      ApiEndpoints.adminApplications,
      query: {
        if (status != null) 'status': status,
        'limit': 100,
      },
      parse: (d) {
        final list = (d['data'] ?? d) as List?;
        return (list ?? [])
            .map((e) => AdminApplication.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList();
      },
    );
  }

  Future<AdminApplication> getApplication(String id) async {
    return _client.get<AdminApplication>(
      ApiEndpoints.adminApplication(id),
      parse: (d) =>
          AdminApplication.fromJson((d['data'] as Map).cast<String, dynamic>()),
    );
  }

  Future<void> reviewApplication(
    String id,
    String action, {
    String? reason,
  }) async {
    final body = action == 'approve'
        ? {'is_founding_farmer': false, 'invite_quota': 3}
        : {'reason': reason ?? ''};
    await _client.post<void>(
      ApiEndpoints.adminApplicationAction(id, action),
      data: body,
      parse: (_) {},
    );
  }

  Future<List<AdminProduct>> getProducts({String? status}) async {
    return _client.get<List<AdminProduct>>(
      ApiEndpoints.adminProducts,
      query: {
        if (status != null) 'status': status,
        'limit': 100,
      },
      parse: (d) {
        final list = (d['data'] ?? d) as List?;
        return (list ?? [])
            .map((e) =>
                AdminProduct.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      },
    );
  }

  Future<AdminProduct> getProduct(String id) async {
    return _client.get<AdminProduct>(
      ApiEndpoints.adminProduct(id),
      parse: (d) =>
          AdminProduct.fromJson((d['data'] as Map).cast<String, dynamic>()),
    );
  }

  Future<void> moderateProduct(
    String id,
    String action, {
    String? reason,
  }) async {
    final body = action == 'reject' ? {'reason': reason ?? ''} : <String, dynamic>{};
    await _client.post<void>(
      ApiEndpoints.adminProductAction(id, action),
      data: body,
      parse: (_) {},
    );
  }

  Future<List<AdminFarmer>> getFarmers({String? status, String? city}) async {
    return _client.get<List<AdminFarmer>>(
      ApiEndpoints.adminFarmers,
      query: {
        if (status != null) 'status': status,
        if (city != null && city.isNotEmpty) 'city': city,
        'limit': 100,
      },
      parse: (d) {
        final list = (d['data'] ?? d) as List?;
        return (list ?? [])
            .map((e) =>
                AdminFarmer.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      },
    );
  }

  Future<AdminFarmerDetail> getFarmer(String id) async {
    return _client.get<AdminFarmerDetail>(
      ApiEndpoints.adminFarmer(id),
      parse: (d) => AdminFarmerDetail.fromJson(
          (d['data'] as Map).cast<String, dynamic>()),
    );
  }

  Future<void> toggleFarmerStatus(String id, String action) async {
    final endpoint = action == 'suspend'
        ? ApiEndpoints.adminFarmerSuspend(id)
        : ApiEndpoints.adminFarmerActivate(id);
    await _client.post<void>(endpoint, parse: (_) {});
  }

  Future<void> updateFarmerQuota(String id, int quota) async {
    await _client.patch<void>(
      ApiEndpoints.adminFarmerInviteQuota(id),
      data: {'invite_quota': quota},
      parse: (_) {},
    );
  }

  Future<List<CityDensity>> getCityDensity() async {
    return _client.get<List<CityDensity>>(
      ApiEndpoints.adminCityDensity,
      parse: (d) {
        final list = (d['data'] ?? d) as List?;
        return (list ?? [])
            .map((e) =>
                CityDensity.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      },
    );
  }

  Future<InviteNode> getInviteNetwork() async {
    return _client.get<InviteNode>(
      ApiEndpoints.adminInviteNetwork,
      parse: (d) => InviteNode.fromJson(
          ((d['data'] ?? d) as Map).cast<String, dynamic>()),
    );
  }

  Future<void> createSubcategory({
    required String parentId,
    required String name,
    required String slug,
  }) async {
    await _client.post<void>(
      ApiEndpoints.adminCategories,
      data: {
        'name': name,
        'slug': slug,
        'parent_id': parentId,
        'icon_name': '',
        'color_hex': '#4CAF50',
        'sort_order': 0,
      },
      parse: (_) {},
    );
  }

  Future<void> deleteCategory(String id) async {
    await _client.delete<void>(
      '${ApiEndpoints.adminCategories}/$id',
      parse: (_) {},
    );
  }

  Future<List<AdminCategory>> getCategories() async {
    return _client.get<List<AdminCategory>>(
      ApiEndpoints.adminCategories,
      parse: (d) {
        final list = (d['data'] ?? d) as List?;
        return (list ?? [])
            .map((e) => AdminCategory.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList();
      },
    );
  }
}
