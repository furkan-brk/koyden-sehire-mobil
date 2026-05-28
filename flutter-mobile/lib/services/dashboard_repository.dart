import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/services/farmer_product_repository.dart';
import 'package:koyden_sehire/models/dashboard_model.dart';
import 'package:koyden_sehire/models/farmer/dashboard_stats.dart';

class DashboardRepository {
  final ApiClient api;
  final FarmerProductRepository products;
  DashboardRepository({required this.api, required this.products});

  /// Hits the new aggregated endpoint and falls back to deriving stats from
  /// `/farmer/products` + `/farmer/invites` if the backend response is
  /// missing fields.
  Future<DashboardData> load() async {
    final stats = await api.get<FarmerDashboardStats>(
      ApiEndpoints.farmerDashboard,
      parse: (env) {
        final data = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        return FarmerDashboardStats.fromJson(data);
      },
    );

    // The backend dashboard response doesn't expose a rejected count, but
    // the UI surfaces it elsewhere — derive lazily if needed (cheap call,
    // and the dashboard payload is already small).
    int rejectedCount = 0;
    try {
      final rejected = await products.list(status: 'rejected');
      rejectedCount = rejected.length;
    } catch (_) {
      // Non-fatal — we'll just show 0.
    }

    return DashboardData.fromStats(stats, rejectedCount: rejectedCount);
  }
}
