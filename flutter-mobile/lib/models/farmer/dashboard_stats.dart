import 'package:koyden_sehire/models/farmer_product_model.dart';

/// Aggregated product counts for the farmer dashboard.
class FarmerProductStats {
  final int active;
  final int pending;
  final int passive;
  final int total;

  const FarmerProductStats({
    required this.active,
    required this.pending,
    required this.passive,
    required this.total,
  });

  factory FarmerProductStats.fromJson(Map<String, dynamic> json) {
    return FarmerProductStats(
      active: (json['active'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      passive: (json['passive'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = FarmerProductStats(
    active: 0,
    pending: 0,
    passive: 0,
    total: 0,
  );
}

/// Invite quota usage for the current farmer.
class FarmerInviteStats {
  final int totalQuota;
  final int usedQuota;
  final int remaining;

  const FarmerInviteStats({
    required this.totalQuota,
    required this.usedQuota,
    required this.remaining,
  });

  factory FarmerInviteStats.fromJson(Map<String, dynamic> json) {
    final total = (json['total_quota'] as num?)?.toInt() ?? 0;
    final used = (json['used_quota'] as num?)?.toInt() ?? 0;
    final remaining = (json['remaining'] as num?)?.toInt() ?? (total - used);
    return FarmerInviteStats(
      totalQuota: total,
      usedQuota: used,
      remaining: remaining < 0 ? 0 : remaining,
    );
  }

  static const empty = FarmerInviteStats(
    totalQuota: 0,
    usedQuota: 0,
    remaining: 0,
  );
}

/// Total engagement (views + favourites) across the farmer's products.
class FarmerEngagementStats {
  final int totalViews;
  final int totalFavorites;

  const FarmerEngagementStats({
    required this.totalViews,
    required this.totalFavorites,
  });

  factory FarmerEngagementStats.fromJson(Map<String, dynamic> json) {
    return FarmerEngagementStats(
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      totalFavorites: (json['total_favorites'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = FarmerEngagementStats(
    totalViews: 0,
    totalFavorites: 0,
  );
}

/// A lightweight summary of one of the farmer's recent products.
/// We reuse [FarmerProductModel] here since the backend payload is
/// structurally identical to other product listings.
typedef RecentProductItem = FarmerProductModel;

/// One bucket in the weekly views series — y axis (count) plotted
/// against day order (x axis).
class DailyCount {
  final DateTime date;
  final int count;

  const DailyCount({required this.date, required this.count});

  factory DailyCount.fromJson(Map<String, dynamic> json) {
    final raw = json['date']?.toString() ?? '';
    return DailyCount(
      date: DateTime.tryParse(raw) ?? DateTime.now(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Aggregated farmer dashboard response (matches the new
/// `GET /api/v1/farmer/dashboard` payload).
class FarmerDashboardStats {
  final FarmerProductStats productStats;
  final FarmerInviteStats inviteStats;
  final FarmerEngagementStats engagementStats;
  final List<RecentProductItem> recentProducts;
  final List<DailyCount> weeklyViews;

  const FarmerDashboardStats({
    required this.productStats,
    required this.inviteStats,
    this.engagementStats = FarmerEngagementStats.empty,
    required this.recentProducts,
    required this.weeklyViews,
  });

  factory FarmerDashboardStats.fromJson(Map<String, dynamic> json) {
    final productStats = json['product_stats'] is Map
        ? FarmerProductStats.fromJson(
            (json['product_stats'] as Map).cast<String, dynamic>(),
          )
        : FarmerProductStats.empty;
    final inviteStats = json['invite_stats'] is Map
        ? FarmerInviteStats.fromJson(
            (json['invite_stats'] as Map).cast<String, dynamic>(),
          )
        : FarmerInviteStats.empty;
    final engagementStats = json['engagement_stats'] is Map
        ? FarmerEngagementStats.fromJson(
            (json['engagement_stats'] as Map).cast<String, dynamic>(),
          )
        : FarmerEngagementStats.empty;
    final recentRaw = (json['recent_products'] as List?) ?? const [];
    final recent = recentRaw
        .whereType<Map>()
        .map((m) => FarmerProductModel.fromJson(m.cast<String, dynamic>()))
        .toList();
    final weeklyRaw = (json['weekly_views'] as List?) ?? const [];
    final weekly = weeklyRaw
        .whereType<Map>()
        .map((m) => DailyCount.fromJson(m.cast<String, dynamic>()))
        .toList();
    return FarmerDashboardStats(
      productStats: productStats,
      inviteStats: inviteStats,
      engagementStats: engagementStats,
      recentProducts: recent,
      weeklyViews: weekly,
    );
  }

  static const empty = FarmerDashboardStats(
    productStats: FarmerProductStats.empty,
    inviteStats: FarmerInviteStats.empty,
    engagementStats: FarmerEngagementStats.empty,
    recentProducts: <RecentProductItem>[],
    weeklyViews: <DailyCount>[],
  );
}
