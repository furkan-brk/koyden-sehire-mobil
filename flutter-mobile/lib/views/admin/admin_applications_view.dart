import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_risk_badge.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_status_badge.dart';
import 'package:koyden_sehire/controllers/admin/admin_applications_controller.dart';
import 'package:koyden_sehire/shared/widgets/search_field.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart' show AppFormatters;

class AdminApplicationsView extends StatefulWidget {
  const AdminApplicationsView({super.key});

  @override
  State<AdminApplicationsView> createState() => _AdminApplicationsViewState();
}

class _AdminApplicationsViewState extends State<AdminApplicationsView> {
  late final AdminApplicationsController _ctrl;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminApplicationsController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminApplicationsController>();
    _searchController.dispose();
    super.dispose();
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
                              'Başvurular',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Referans kodu ile gelen üretici başvurularını inceleyin.',
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
                    Expanded(flex: 4, child: _ColLabel('AD SOYAD / İŞLETME')),
                    Expanded(flex: 2, child: _ColLabel('ŞEHİR')),
                    Expanded(flex: 2, child: _ColLabel('DAVET KODU')),
                    SizedBox(width: 96, child: _ColLabel('DURUM')),
                    SizedBox(width: 80, child: _ColLabel('RİSK')),
                    Expanded(flex: 2, child: _ColLabel('TARİH')),
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
                      message: 'Henüz başvuru bulunmuyor.');
                }
                if (isDesktop) {
                  return RefreshIndicator(
                    onRefresh: _ctrl.load,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final app = items[i];
                        return InkWell(
                          onTap: () => context
                              .push('/admin/applications/${app.id}'),
                          hoverColor: AppColors.surfaceContainerLow
                              .withValues(alpha: 0.6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.fullName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        app.businessName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${app.city}, ${app.district}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.xs),
                                    ),
                                    child: Text(
                                      app.inviteCode ?? '—',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 96,
                                  child:
                                      AdminStatusBadge(status: app.status),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: app.riskLevel != null
                                      ? AdminRiskBadge(
                                          level: app.riskLevel!)
                                      : const SizedBox.shrink(),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    AppFormatters.date(app.createdAt),
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
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
                      final app = items[i];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              AdminStatusBadge(status: app.status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(app.businessName,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 12,
                                      color: cs.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text('${app.city}, ${app.district}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.calendar_today_outlined,
                                      size: 12,
                                      color: cs.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text(
                                    AppFormatters.date(app.createdAt),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant),
                                  ),
                                  if (app.riskLevel != null) ...[
                                    const SizedBox(width: 8),
                                    AdminRiskBadge(level: app.riskLevel!),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context
                              .push('/admin/applications/${app.id}'),
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
