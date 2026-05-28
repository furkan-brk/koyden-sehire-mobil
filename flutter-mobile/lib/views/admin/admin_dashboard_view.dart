import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/admin/admin_dashboard_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_stat_card.dart';
import 'package:koyden_sehire/controllers/admin/admin_dashboard_controller.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  late final AdminDashboardController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminDashboardController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminDashboardController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const AppLoading();
      }
      if (_ctrl.error.value.isNotEmpty) {
        return AppErrorWidget(
          message: _ctrl.error.value,
          onRetry: _ctrl.load,
        );
      }

      final data = _ctrl.data.value;
      if (data == null) return const SizedBox.shrink();

      return RefreshIndicator(
        onRefresh: _ctrl.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Sistemdeki genel operasyonel durum ve metrikler.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _StatsGrid(stats: data.stats),
              if (data.applicationsByDay.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ApplicationsChart(points: data.applicationsByDay),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        'Bekleyen Başvurular',
        stats.pendingApplications,
        Icons.access_time_outlined,
        stats.todayApplications > 0 ? '+${stats.todayApplications} bugün' : null,
      ),
      ('Aktif Çiftçiler', stats.activeFarmers, Icons.people_outline, null),
      ('Bekleyen Ürünler', stats.pendingProducts, Icons.shield_outlined, null),
      ('Yayındaki Ürünler', stats.activeProducts, Icons.check_circle_outline, null),
      ('Askıya Alınanlar', stats.suspendedFarmers, Icons.warning_amber_outlined, null),
      ('Bugünkü Başvurular', stats.todayApplications, Icons.trending_up, null),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards
          .map((c) => AdminStatCard(
                title: c.$1,
                value: c.$2,
                icon: c.$3,
                trend: c.$4,
              ))
          .toList(),
    );
  }
}

class _ApplicationsChart extends StatelessWidget {
  final List<ChartPoint> points;
  const _ApplicationsChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son Başvuru Trendi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            points[i].name,
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
                      isCurved: true,
                      color: AppColors.success,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
