import 'package:koyden_sehire/models/farmer_product_model.dart';
import 'package:koyden_sehire/models/farmer/dashboard_stats.dart';

/// Farmer dashboard view-model.
///
/// Mirrors `GET /api/v1/farmer/dashboard`. Older callers that consumed
/// the legacy locally-derived counts continue to work via the top-level
/// convenience getters ([activeCount], [pendingCount], ...).
class DashboardData {
  final FarmerProductStats productStats;
  final FarmerInviteStats inviteStats;
  final FarmerEngagementStats engagementStats;
  final List<FarmerProductModel> recentProducts;
  final List<DailyCount> weeklyViews;

  /// We no longer get a `rejected` count from the backend's `product_stats`,
  /// but the legacy UI references it — keep it as a derived field that can
  /// be supplied separately when known.
  final int rejectedCount;

  const DashboardData({
    required this.productStats,
    required this.inviteStats,
    this.engagementStats = FarmerEngagementStats.empty,
    required this.recentProducts,
    required this.weeklyViews,
    this.rejectedCount = 0,
  });

  factory DashboardData.fromStats(
    FarmerDashboardStats stats, {
    int rejectedCount = 0,
  }) {
    return DashboardData(
      productStats: stats.productStats,
      inviteStats: stats.inviteStats,
      engagementStats: stats.engagementStats,
      recentProducts: stats.recentProducts,
      weeklyViews: stats.weeklyViews,
      rejectedCount: rejectedCount,
    );
  }

  // ── Legacy convenience getters (used by existing UI) ──
  int get activeCount => productStats.active;
  int get pendingCount => productStats.pending;
  int get hiddenCount => productStats.passive;
  int get inviteRemaining => inviteStats.remaining;
}
