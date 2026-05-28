import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_status_badge.dart';
import 'package:koyden_sehire/controllers/admin/admin_farmers_controller.dart';
import 'package:koyden_sehire/shared/widgets/search_field.dart';

class AdminFarmersView extends StatefulWidget {
  const AdminFarmersView({super.key});

  @override
  State<AdminFarmersView> createState() => _AdminFarmersViewState();
}

class _AdminFarmersViewState extends State<AdminFarmersView> {
  late final AdminFarmersController _ctrl;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminFarmersController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminFarmersController>();
    _searchController.dispose();
    super.dispose();
  }

  Color _trustColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Üreticiler',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sistemdeki aktif üreticilerin listesi ve yönetimi.',
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
                        onPressed: _ctrl.load,
                        icon: const Icon(Icons.refresh_outlined, size: 16),
                        label: const Text('Yenile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 16 : 12),
                  SearchField(
                    controller: _searchController,
                    hintText: 'İsim, şehir veya davet kodu ara...',
                    onChanged: (v) => _ctrl.search.value = v,
                    onClear: () => _ctrl.search.value = '',
                  ),
                  SizedBox(height: isDesktop ? 16 : 8),
                ],
              ),
            ),
            if (isDesktop) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                color: AppColors.surfaceContainerLow,
                child: const Row(
                  children: [
                    SizedBox(width: 44),
                    SizedBox(width: 12),
                    Expanded(flex: 3, child: _ColLabel('ÜRETİCİ')),
                    Expanded(flex: 2, child: _ColLabel('ŞEHİR')),
                    SizedBox(width: 80, child: _ColLabel('ÜRÜNLER')),
                    SizedBox(width: 100, child: _ColLabel('DAVET KOTASI')),
                    SizedBox(width: 96, child: _ColLabel('DURUM')),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value) return const AppLoading();
                if (_ctrl.error.value.isNotEmpty) {
                  return AppErrorWidget(
                      message: _ctrl.error.value, onRetry: _ctrl.load);
                }
                final items = _ctrl.filteredItems;
                if (items.isEmpty) {
                  return const AppEmptyWidget(
                      message: 'Henüz üretici bulunmuyor.');
                }
                if (isDesktop) {
                  return RefreshIndicator(
                    onRefresh: _ctrl.load,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final farmer = items[i];
                        final tc = _trustColor(farmer.trustScore);
                        return InkWell(
                          onTap: () =>
                              context.push('/admin/farmers/${farmer.id}'),
                          hoverColor: AppColors.surfaceContainerLow
                              .withValues(alpha: 0.6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            child: Row(
                              children: [
                                // Trust score circle
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: tc.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    farmer.trustScore.toStringAsFixed(0),
                                    style: TextStyle(
                                      color: tc,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name + founding badge
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              farmer.fullName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14),
                                            ),
                                            if (farmer.isFoundingFarmer)
                                              Row(
                                                children: [
                                                  const Icon(Icons.star,
                                                      size: 11,
                                                      color: AppColors.warning),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Kurucu Üretici',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: cs
                                                            .onSurfaceVariant),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // City
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${farmer.city}, ${farmer.district}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                // Product count
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '${farmer.productCount} ürün',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                // Invite quota
                                SizedBox(
                                  width: 100,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: farmer.inviteQuota > 0
                                                ? farmer.usedInvites /
                                                    farmer.inviteQuota
                                                : 0,
                                            backgroundColor: AppColors
                                                .outlineVariant
                                                .withValues(alpha: 0.5),
                                            color: AppColors.primary,
                                            minHeight: 5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${farmer.usedInvites}/${farmer.inviteQuota}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                // Status
                                SizedBox(
                                  width: 96,
                                  child:
                                      AdminStatusBadge(status: farmer.status),
                                ),
                                // Chevron
                                SizedBox(
                                  width: 48,
                                  child: Icon(Icons.chevron_right,
                                      color: cs.onSurfaceVariant, size: 20),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                // Mobile
                return RefreshIndicator(
                  onRefresh: _ctrl.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final farmer = items[i];
                      final tc = _trustColor(farmer.trustScore);
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: tc.withValues(alpha: 0.15),
                            child: Text(
                              farmer.trustScore.toStringAsFixed(0),
                              style: TextStyle(
                                color: tc,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  farmer.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (farmer.isFoundingFarmer)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.star,
                                      size: 16, color: AppColors.warning),
                                ),
                              AdminStatusBadge(status: farmer.status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 12, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text('${farmer.city}, ${farmer.district}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.inventory_2_outlined,
                                      size: 12, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text('${farmer.productCount} ürün',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.people_outline,
                                      size: 12, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text(
                                      '${farmer.usedInvites}/${farmer.inviteQuota}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/admin/farmers/${farmer.id}'),
                        ),
                      );
                    },
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

class _ColLabel extends StatelessWidget {
  final String text;
  const _ColLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
