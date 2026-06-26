class DashboardStats {
  final int totalFarmers;
  final int activeFarmers;
  final int suspendedFarmers;
  final int pendingApplications;
  final int todayApplications;
  final int pendingProducts;
  final int activeProducts;
  final int totalProducts;

  const DashboardStats({
    required this.totalFarmers,
    required this.activeFarmers,
    required this.suspendedFarmers,
    required this.pendingApplications,
    required this.todayApplications,
    required this.pendingProducts,
    required this.activeProducts,
    required this.totalProducts,
  });
}

class ChartPoint {
  final String name;
  final double value;

  const ChartPoint({required this.name, required this.value});
}

class AdminDashboardData {
  final DashboardStats stats;
  final List<ChartPoint> applicationsByDay;
  final List<ChartPoint> productsByCategory;
  final List<ChartPoint> producersByCity;

  const AdminDashboardData({
    required this.stats,
    required this.applicationsByDay,
    required this.productsByCategory,
    required this.producersByCity,
  });
}
