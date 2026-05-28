import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/admin/admin_category_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/controllers/admin/admin_categories_controller.dart';

class AdminCategoriesView extends StatefulWidget {
  const AdminCategoriesView({super.key});

  @override
  State<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends State<AdminCategoriesView> {
  late final AdminCategoriesController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminCategoriesController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminCategoriesController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final hp = isDesktop ? 24.0 : 16.0;
        return Obx(() {
          if (_ctrl.isLoading.value) return const AppLoading();
          if (_ctrl.error.value.isNotEmpty) {
            return AppErrorWidget(
                message: _ctrl.error.value, onRetry: _ctrl.load);
          }
          final items = _ctrl.items;
          final parents =
              items.where((c) => c.parentId == null).toList();

          return RefreshIndicator(
            onRefresh: _ctrl.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(hp, hp, hp, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kategoriler',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Ürünlerin listelendiği ana ve alt kategorileri görüntüleyin.',
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
                        const SizedBox(height: 12),
                        // Read-only info banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed
                                .withValues(alpha: 0.25),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Bu ekran yalnızca görüntüleme amaçlıdır.',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isDesktop ? 20 : 12),
                      ],
                    ),
                  ),
                ),
                if (isDesktop)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 500,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                            _CategoryCard(category: parents[i]),
                        childCount: parents.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                            _CategoryCard(category: parents[i]),
                        childCount: parents.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AdminCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.category_outlined,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                _StatusChip(active: category.active),
              ],
            ),
            if (category.children.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: category.children.map((child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: child.active
                          ? AppColors.secondaryContainer
                              .withValues(alpha: 0.5)
                          : AppColors.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: child.active
                            ? AppColors.secondary
                                .withValues(alpha: 0.3)
                            : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: child.active
                                ? AppColors.secondary
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!child.active) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.visibility_off_outlined,
                              size: 10,
                              color: cs.onSurfaceVariant),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.outlineVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.success : AppColors.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Aktif' : 'Pasif',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.success : AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
