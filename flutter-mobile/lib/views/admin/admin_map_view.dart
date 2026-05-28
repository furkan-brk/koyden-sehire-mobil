import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/controllers/admin/admin_map_controller.dart';
import 'package:koyden_sehire/shared/widgets/search_field.dart';

class AdminMapView extends StatefulWidget {
  const AdminMapView({super.key});

  @override
  State<AdminMapView> createState() => _AdminMapViewState();
}

class _AdminMapViewState extends State<AdminMapView> {
  late final AdminMapController _ctrl;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminMapController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminMapController>();
    _searchController.dispose();
    super.dispose();
  }

  Color _riskColor(String level) => switch (level) {
        'high' => AppColors.error,
        'medium' => AppColors.warning,
        _ => AppColors.success,
      };

  String _riskLabel(String level) => switch (level) {
        'high' => 'Yüksek',
        'medium' => 'Orta',
        _ => 'Düşük',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final hp = isDesktop ? 24.0 : 16.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hp, hp, hp, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Şehir Yoğunluğu',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Bölgeye göre üretici dağılımı ve risk analizi.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _ctrl.load,
                        icon: const Icon(Icons.refresh_outlined,
                            size: 16),
                        label: const Text('Yenile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 16 : 12),
                  SearchField(
                    controller: _searchController,
                    hintText: 'Şehir ara...',
                    onChanged: (v) => _ctrl.search.value = v,
                    onClear: () => _ctrl.search.value = '',
                  ),
                  SizedBox(height: isDesktop ? 16 : 8),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value) return const AppLoading();
                if (_ctrl.error.value.isNotEmpty) {
                  return AppErrorWidget(
                      message: _ctrl.error.value,
                      onRetry: _ctrl.load);
                }
                final items = _ctrl.filteredItems;
                if (items.isEmpty) {
                  return const AppEmptyWidget(
                      message: 'Veri bulunamadı.');
                }

                if (isDesktop) {
                  // Desktop: bar chart top + grid bottom
                  final sorted = [...items]
                    ..sort((a, b) =>
                        b.farmerCount.compareTo(a.farmerCount));
                  final maxCount = sorted.first.farmerCount;

                  return RefreshIndicator(
                    onRefresh: _ctrl.load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bar chart card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Üretici Dağılımı — En Yoğun Şehirler',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight.w600),
                                  ),
                                  const SizedBox(height: 16),
                                  ...sorted.take(8).map((city) {
                                    final frac = maxCount > 0
                                        ? city.farmerCount / maxCount
                                        : 0.0;
                                    final rc =
                                        _riskColor(city.riskLevel);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              city.city,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w500),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      3),
                                              child:
                                                  LinearProgressIndicator(
                                                value: frac,
                                                backgroundColor:
                                                    AppColors.outlineVariant
                                                        .withValues(
                                                            alpha: 0.3),
                                                color:
                                                    AppColors.primary,
                                                minHeight: 8,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 32,
                                            child: Text(
                                              '${city.farmerCount}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: rc.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.pill),
                                            ),
                                            child: Text(
                                              _riskLabel(city.riskLevel),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: rc,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Tüm Şehirler',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 280,
                              mainAxisExtent: 120,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: items.length,
                            itemBuilder: (ctx, i) =>
                                _CityCard(city: items[i], riskColor: _riskColor, riskLabel: _riskLabel),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Mobile
                return RefreshIndicator(
                  onRefresh: _ctrl.load,
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisExtent: 120,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => _CityCard(
                        city: items[i],
                        riskColor: _riskColor,
                        riskLabel: _riskLabel),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _CityCard extends StatelessWidget {
  final dynamic city;
  final Color Function(String) riskColor;
  final String Function(String) riskLabel;
  const _CityCard(
      {required this.city,
      required this.riskColor,
      required this.riskLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = riskColor(city.riskLevel as String);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    city.city as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    riskLabel(city.riskLevel as String),
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatRow(
              icon: Icons.people_outline,
              label: 'Üretici',
              value: (city.farmerCount as int).toString(),
              cs: cs,
            ),
            const SizedBox(height: 4),
            _StatRow(
              icon: Icons.assignment_outlined,
              label: 'Bekleyen',
              value:
                  (city.pendingApplications as int).toString(),
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  const _StatRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
