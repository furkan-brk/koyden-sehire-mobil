import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/models/admin/admin_dashboard_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';

class AdminDashboardController extends GetxController {
  final AdminRepository _repo;
  AdminDashboardController(this._repo);

  final data = Rx<AdminDashboardData?>(null);
  final isLoading = true.obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      data.value = await _repo.getDashboard();
    } catch (e) {
      // In debug mode fall back to synthetic data so charts are always
      // visible during development without a running backend.
      if (kDebugMode) {
        data.value = _syntheticData();
      } else {
        error.value = e.toString();
      }
    } finally {
      isLoading.value = false;
    }
  }

  static AdminDashboardData _syntheticData() {
    return AdminDashboardData(
      stats: const DashboardStats(
        totalFarmers: 42,
        activeFarmers: 36,
        suspendedFarmers: 3,
        pendingApplications: 7,
        todayApplications: 2,
        pendingProducts: 14,
        activeProducts: 118,
        totalProducts: 135,
      ),
      applicationsByDay: _dailySeries([3, 1, 4, 2, 6, 5, 3, 8, 4, 2, 7, 5, 2, 3]),
      productsByCategory: const [
        ChartPoint(name: 'Sebze', value: 38),
        ChartPoint(name: 'Meyve', value: 27),
        ChartPoint(name: 'Tahıl', value: 19),
        ChartPoint(name: 'Süt Ürünleri', value: 15),
        ChartPoint(name: 'Bakliyat', value: 11),
        ChartPoint(name: 'Diğer', value: 8),
      ],
      producersByCity: const [
        ChartPoint(name: 'İzmir', value: 9),
        ChartPoint(name: 'Ankara', value: 7),
        ChartPoint(name: 'Bursa', value: 6),
        ChartPoint(name: 'Antalya', value: 5),
        ChartPoint(name: 'Konya', value: 4),
        ChartPoint(name: 'Mersin', value: 3),
        ChartPoint(name: 'Aydın', value: 2),
      ],
    );
  }

  static List<ChartPoint> _dailySeries(List<num> counts) {
    final now = DateTime.now();
    return List.generate(counts.length, (i) {
      final day = now.subtract(Duration(days: counts.length - 1 - i));
      final label = '${day.day.toString().padLeft(2, '0')}/'
          '${day.month.toString().padLeft(2, '0')}';
      return ChartPoint(name: label, value: counts[i].toDouble());
    });
  }
}
