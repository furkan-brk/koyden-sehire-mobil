import 'package:flutter/material.dart';
import 'package:koyden_sehire/shared/utils/responsive.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/admin/audit_log_controller.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart' show AppFormatters;
import 'package:koyden_sehire/models/admin/audit_log.dart';
import 'package:koyden_sehire/services/audit_log_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';

const Map<String, String> _actionLabels = {
  'product.approved': 'Ürün Onaylandı',
  'product.rejected': 'Ürün Reddedildi',
  'farmer.suspended': 'Üretici Askıya Alındı',
  'farmer.approved': 'Üretici Onaylandı',
  'account.deleted': 'Hesap Silindi',
};

String _actionLabel(String action) => _actionLabels[action] ?? action;

class AdminAuditLogView extends StatefulWidget {
  const AdminAuditLogView({super.key});

  @override
  State<AdminAuditLogView> createState() => _AdminAuditLogViewState();
}

class _AdminAuditLogViewState extends State<AdminAuditLogView> {
  late final AuditLogController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AuditLogRepository>();
    _ctrl = Get.put(AuditLogController(repo));
  }

  @override
  void dispose() {
    Get.delete<AuditLogController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppBreakpoints.desktop;
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
                              'Denetim Günlüğü',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Yöneticiler tarafından gerçekleştirilen aksiyonların kaydı.',
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
                  Obx(() => DropdownButtonFormField<String?>(
                        // ignore: deprecated_member_use
                        value: _ctrl.actionFilter.value,
                        isDense: true,
                        decoration: const InputDecoration(
                          prefixIcon:
                              Icon(Icons.filter_list_outlined, size: 18),
                          hintText: 'Aksiyona göre filtrele',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm Aksiyonlar'),
                          ),
                          ..._actionLabels.entries.map(
                            (e) => DropdownMenuItem<String?>(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          ),
                        ],
                        onChanged: _ctrl.setActionFilter,
                      )),
                  SizedBox(height: isDesktop ? 16 : 8),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value) return const AppLoading();
                if (_ctrl.error.value.isNotEmpty) {
                  return AppErrorWidget(
                      message: _ctrl.error.value, onRetry: _ctrl.load);
                }
                final items = _ctrl.logs;
                if (items.isEmpty) {
                  return const AppEmptyWidget(
                    message: 'Henüz denetim kaydı bulunmuyor.',
                    icon: Icons.history,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _ctrl.load,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      if (i == items.length) {
                        return _LoadMoreFooter(controller: _ctrl);
                      }
                      return _AuditLogTile(log: items[i]);
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

class _AuditLogTile extends StatefulWidget {
  final AuditLog log;
  const _AuditLogTile({required this.log});

  @override
  State<_AuditLogTile> createState() => _AuditLogTileState();
}

class _AuditLogTileState extends State<_AuditLogTile> {
  bool _expanded = false;

  Color _actionColor(String action) {
    if (action.endsWith('.approved')) return AppColors.success;
    if (action.endsWith('.rejected') ||
        action.endsWith('.suspended') ||
        action.endsWith('.deleted')) {
      return AppColors.error;
    }
    return AppColors.primary;
  }

  IconData _actionIcon(String action) {
    if (action.endsWith('.approved')) return Icons.check_circle_outline;
    if (action.endsWith('.rejected')) return Icons.cancel_outlined;
    if (action.endsWith('.suspended')) return Icons.block;
    if (action.endsWith('.deleted')) return Icons.delete_outline;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final log = widget.log;
    final color = _actionColor(log.action);
    final hasMeta = log.meta != null && log.meta!.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(_actionIcon(log.action), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _actionLabel(log.action),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                      Text(
                        AppFormatters.date(log.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          log.actorName.isEmpty ? '—' : log.actorName,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.label_outline,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${log.targetType}: ${log.targetId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (hasMeta) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _expanded ? 'Gizle' : 'Detayları Göster',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                              color: AppColors.outlineVariant, width: 1),
                        ),
                        child: Text(
                          log.meta.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  final AuditLogController controller;
  const _LoadMoreFooter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasMore.value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Tüm kayıtlar yüklendi',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        );
      }
      if (controller.isLoadingMore.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: AppLoading(),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton.icon(
            onPressed: controller.loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Daha Fazla Yükle'),
          ),
        ),
      );
    });
  }
}
