import 'package:flutter/material.dart';
import 'package:koyden_sehire/shared/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/admin/admin_invite_network_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/controllers/admin/admin_invite_network_controller.dart';

// Max indent to prevent horizontal overflow on deep trees
const double _kMaxIndent = 96.0;
const double _kIndentStep = 20.0;

class AdminInviteNetworkView extends StatefulWidget {
  const AdminInviteNetworkView({super.key});

  @override
  State<AdminInviteNetworkView> createState() =>
      _AdminInviteNetworkViewState();
}

class _AdminInviteNetworkViewState
    extends State<AdminInviteNetworkView> {
  late final AdminInviteNetworkController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminInviteNetworkController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminInviteNetworkController>();
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
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Davet Ağı',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Üreticiler arasındaki davet ilişkileri ve ağ yapısı.',
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
                final root = _ctrl.root.value;
                if (root == null) {
                  return const AppEmptyWidget(
                      message: 'Ağ verisi bulunamadı.');
                }
                return RefreshIndicator(
                  onRefresh: _ctrl.load,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                    child: _NodeTree(node: root, depth: 0),
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

class _NodeTree extends StatefulWidget {
  final InviteNode node;
  final int depth;
  const _NodeTree({required this.node, required this.depth});

  @override
  State<_NodeTree> createState() => _NodeTreeState();
}

class _NodeTreeState extends State<_NodeTree> {
  bool _expanded = true;

  Color _trustColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final node = widget.node;
    final hasChildren = node.invitees.isNotEmpty;
    // Cap indent to prevent overflow on deep trees
    final indentWidth =
        (widget.depth * _kIndentStep).clamp(0.0, _kMaxIndent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indentWidth),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () =>
                  context.push('/admin/farmers/${node.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Depth indicator line (for nested nodes)
                    if (widget.depth > 0) ...[
                      Container(
                        width: 3,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                    // Founding farmer icon
                    if (node.isFoundingFarmer)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.hub,
                            size: 15, color: AppColors.primary),
                      ),
                    // Name + city
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          Text(
                            node.city,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    // Invite code chip
                    if (node.inviteCode != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          node.inviteCode!,
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: cs.onSurfaceVariant),
                        ),
                      ),
                    // Child count
                    if (hasChildren)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed
                              .withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${node.invitees.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    // Trust score
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _trustColor(node.trustScore)
                            .withValues(alpha: 0.12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        node.trustScore.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _trustColor(node.trustScore),
                        ),
                      ),
                    ),
                    // Expand/collapse
                    if (hasChildren) ...[
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _expanded = !_expanded),
                        child: Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && _expanded)
          ...node.invitees.map(
            (child) =>
                _NodeTree(node: child, depth: widget.depth + 1),
          ),
      ],
    );
  }
}
