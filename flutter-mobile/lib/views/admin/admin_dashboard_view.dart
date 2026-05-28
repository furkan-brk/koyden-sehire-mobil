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
    return Obx(() {
      if (_ctrl.isLoading.value) return const AppLoading();
      if (_ctrl.error.value.isNotEmpty) {
        return AppErrorWidget(message: _ctrl.error.value, onRetry: _ctrl.load);
      }
      final data = _ctrl.data.value;
      if (data == null) return const SizedBox.shrink();

      return RefreshIndicator(
        onRefresh: _ctrl.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(onRefresh: _ctrl.load),
              const SizedBox(height: 24),
              _StatsGrid(stats: data.stats),
              if (data.applicationsByDay.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ApplicationsChart(points: data.applicationsByDay),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    });
  }
}

// ── Page header ────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  const _DashboardHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Başvuru, üretici ve ürün durumlarını genel olarak takip edin.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_outlined, size: 16),
          label: const Text('Yenile'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── Stats grid ─────────────────────────────────────────────────────────────

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
        AppColors.warning,
      ),
      (
        'Aktif Çiftçiler',
        stats.activeFarmers,
        Icons.people_outline,
        null,
        AppColors.primary,
      ),
      (
        'Bekleyen Ürünler',
        stats.pendingProducts,
        Icons.shield_outlined,
        null,
        AppColors.secondary,
      ),
      (
        'Yayındaki Ürünler',
        stats.activeProducts,
        Icons.check_circle_outline,
        null,
        AppColors.success,
      ),
      (
        'Askıya Alınanlar',
        stats.suspendedFarmers,
        Icons.warning_amber_outlined,
        null,
        AppColors.error,
      ),
      (
        'Bugünkü Başvurular',
        stats.todayApplications,
        Icons.trending_up,
        null,
        AppColors.primaryContainer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols;
        if (constraints.maxWidth >= 900) {
          cols = 3;
        } else if (constraints.maxWidth >= 560) {
          cols = 2;
        } else {
          cols = 1;
        }
        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: constraints.maxWidth >= 900 ? 1.8 : 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards
              .map((c) => AdminStatCard(
                    title: c.$1,
                    value: c.$2,
                    icon: c.$3,
                    trend: c.$4,
                    color: c.$5,
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Chart ──────────────────────────────────────────────────────────────────

class _ApplicationsChart extends StatelessWidget {
  final List<ChartPoint> points;
  const _ApplicationsChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Başvuru Trendi',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Son günlerde gelen başvuru sayısı',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
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
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              points[i].name,
                              style: TextStyle(
                                  fontSize: 10, color: cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.value.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: AppColors.surfaceContainerLowest,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
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
