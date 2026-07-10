import 'package:flutter/material.dart';
import 'package:koyden_sehire/shared/utils/responsive.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/admin/admin_dashboard_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/echart/echart.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_chart_options.dart';
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

      final s = data.stats;

      // Entire dashboard scrolls as one — otherwise a fixed (non-scrolling) KPI
      // header would, at narrow widths, grow tall enough to squeeze the charts'
      // Expanded to zero height and overflow the Column.
      return RefreshIndicator(
        onRefresh: _ctrl.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeader(onRefresh: _ctrl.load),
                    const SizedBox(height: 16),
                    _StatsGrid(stats: s),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.totalProducts > 0 || s.totalFarmers > 0) ...[
                      _GaugesRow(stats: s),
                      const SizedBox(height: 14),
                    ],
                    if (data.applicationsByDay.isNotEmpty) ...[
                      _ChartCard(
                        title: 'Başvuru Trendi',
                        subtitle: 'Son 14 günde gelen başvuru sayısı',
                        child: EChart(
                          option: applicationsTrendOption(
                              data.applicationsByDay),
                          height: 220,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (data.productsByCategory.isNotEmpty ||
                        data.producersByCity.isNotEmpty) ...[
                      _SecondaryChartsRow(
                        categoryPoints: data.productsByCategory,
                        cityPoints: data.producersByCity,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (s.totalProducts > 0)
                      _ChartCard(
                        title: 'Ürün Durumu',
                        subtitle:
                            'Toplam ${s.totalProducts} ürünün yayın durumuna göre dağılımı',
                        child: EChart(
                          option: productStatusDonutOption(s),
                          height: 300,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Page header ──────────────────────────────────────────────────────────────

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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            minimumSize: Size.zero,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── KPI stats grid ───────────────────────────────────────────────────────────

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
        stats.todayApplications > 0
            ? '+${stats.todayApplications} bugün'
            : null,
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
        final w = constraints.maxWidth;
        final int cols;
        final double aspect;
        if (w >= AppBreakpoints.wide) {
          cols = 6;
          aspect = 1.9;
        } else if (w >= AppBreakpoints.desktop) {
          cols = 3;
          aspect = 1.9;
        } else if (w >= AppBreakpoints.medium) {
          cols = 2;
          aspect = 1.8;
        } else {
          cols = 1;
          aspect = 2.6;
        }
        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspect,
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

// ── Gauge row (two side-by-side ratio gauges) ────────────────────────────────

class _GaugesRow extends StatelessWidget {
  final DashboardStats stats;
  const _GaugesRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;

      final productGauge = stats.totalProducts > 0
          ? _ChartCard(
              title: 'Aktif Ürün Oranı',
              subtitle:
                  '${stats.activeProducts} / ${stats.totalProducts} ürün yayında',
              child: EChart(
                option: ratioGaugeOption(
                  title: 'Aktif Ürünler',
                  value: stats.activeProducts,
                  total: stats.totalProducts,
                ),
                height: 200,
              ),
            )
          : null;

      final farmerGauge = stats.totalFarmers > 0
          ? _ChartCard(
              title: 'Aktif Çiftçi Oranı',
              subtitle:
                  '${stats.activeFarmers} / ${stats.totalFarmers} çiftçi aktif',
              child: EChart(
                option: ratioGaugeOption(
                  title: 'Aktif Çiftçiler',
                  value: stats.activeFarmers,
                  total: stats.totalFarmers,
                ),
                height: 200,
              ),
            )
          : null;

      if (productGauge == null && farmerGauge == null) {
        return const SizedBox.shrink();
      }
      if (productGauge == null) return farmerGauge!;
      if (farmerGauge == null) return productGauge;

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: productGauge),
            const SizedBox(width: 14),
            Expanded(child: farmerGauge),
          ],
        );
      } else {
        return Column(children: [
          productGauge,
          const SizedBox(height: 14),
          farmerGauge,
        ]);
      }
    });
  }
}

// ── Reusable chart card shell ────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Secondary charts: category columns + city horizontal bars ────────────────

class _SecondaryChartsRow extends StatelessWidget {
  final List<ChartPoint> categoryPoints;
  final List<ChartPoint> cityPoints;

  const _SecondaryChartsRow({
    required this.categoryPoints,
    required this.cityPoints,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;

      final categoryCard = categoryPoints.isNotEmpty
          ? _ChartCard(
              title: 'Kategoriye Göre Ürünler',
              subtitle: 'Aktif ürünlerin kategorilere dağılımı',
              child: EChart(
                option: productsByCategoryOption(categoryPoints),
                height: 220,
              ),
            )
          : null;

      final chartH =
          (cityPoints.length * 26.0).clamp(180.0, 320.0);
      final cityCard = cityPoints.isNotEmpty
          ? _ChartCard(
              title: 'Şehre Göre Üreticiler',
              subtitle: 'Aktif üreticilerin şehirlere göre dağılımı',
              child: EChart(
                option: producersByCityOption(cityPoints),
                height: chartH,
              ),
            )
          : null;

      if (categoryCard == null && cityCard == null) {
        return const SizedBox.shrink();
      }
      if (categoryCard == null) return cityCard!;
      if (cityCard == null) return categoryCard;

      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: categoryCard),
            const SizedBox(width: 14),
            Expanded(child: cityCard),
          ],
        );
      }
      return Column(children: [
        categoryCard,
        const SizedBox(height: 14),
        cityCard,
      ]);
    });
  }
}
