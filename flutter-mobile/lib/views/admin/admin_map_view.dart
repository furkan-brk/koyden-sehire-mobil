import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/app/theme.dart';
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

  Color _riskColor(String level) {
    return switch (level) {
      'high' => AppColors.error,
      'medium' => AppColors.warning,
      _ => AppColors.success,
    };
  }

  String _riskLabel(String level) {
    return switch (level) {
      'high' => 'Yüksek Risk',
      'medium' => 'Orta Risk',
      _ => 'Düşük Risk',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Şehir Yoğunluğu',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Bölgeye göre üretici dağılımı ve risk analizi.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SearchField(
                controller: _searchController,
                hintText: 'Şehir ara...',
                onChanged: (v) => _ctrl.search.value = v,
                onClear: () => _ctrl.search.value = '',
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (_ctrl.isLoading.value) {
              return const AppLoading();
            }
            if (_ctrl.error.value.isNotEmpty) {
              return AppErrorWidget(
                message: _ctrl.error.value,
                onRetry: _ctrl.load,
              );
            }
            final items = _ctrl.filteredItems;
            if (items.isEmpty) {
              return const AppEmptyWidget(message: 'Veri bulunamadı.');
            }
            return RefreshIndicator(
              onRefresh: _ctrl.load,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final city = items[i];
                  final color = _riskColor(city.riskLevel);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  city.city,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _riskLabel(city.riskLevel),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _StatRow(
                            icon: Icons.people_outline,
                            label: 'Üretici',
                            value: city.farmerCount.toString(),
                          ),
                          const SizedBox(height: 4),
                          _StatRow(
                            icon: Icons.assignment_outlined,
                            label: 'Bekleyen Başvuru',
                            value: city.pendingApplications.toString(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
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
