import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_risk_badge.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_status_badge.dart';
import 'package:koyden_sehire/controllers/admin/admin_applications_controller.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart' show AppFormatters;

class AdminApplicationsView extends StatefulWidget {
  const AdminApplicationsView({super.key});

  @override
  State<AdminApplicationsView> createState() =>
      _AdminApplicationsViewState();
}

class _AdminApplicationsViewState
    extends State<AdminApplicationsView> {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Başvurular',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Sisteme kayıt olmak isteyen üreticilerin listesi.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'İsim, şehir veya davet kodu ara...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => _ctrl.search.value = v,
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
              return const AppEmptyWidget(message: 'Henüz başvuru bulunmuyor.');
            }
            return RefreshIndicator(
              onRefresh: _ctrl.load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                              style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                '${app.city}, ${app.district}',
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.calendar_today_outlined,
                                  size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                AppFormatters.date(app.createdAt),
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant),
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
                      onTap: () =>
                          context.push('/admin/applications/${app.id}'),
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
