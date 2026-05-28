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

  Future<void> _showAddSubcategoryDialog(
    BuildContext context,
    AdminCategory category,
  ) async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddSubcategoryDialog(
        categoryName: category.name,
        onSave: (name) => _ctrl.addSubcategory(category.id, name),
      ),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt kategori eklendi.')),
      );
    }
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
                                    'Ürünlerin listelendiği ana ve alt kategorileri yönetin.',
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
                        (ctx, i) => _CategoryCard(
                          category: parents[i],
                          onAdd: () => _showAddSubcategoryDialog(
                              context, parents[i]),
                        ),
                        childCount: parents.length,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hp, 0, hp, hp),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CategoryCard(
                          category: parents[i],
                          onAdd: () => _showAddSubcategoryDialog(
                              context, parents[i]),
                        ),
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

// ── Category Card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final AdminCategory category;
  final VoidCallback onAdd;
  const _CategoryCard({required this.category, required this.onAdd});

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
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 13),
                    label: const Text('Ekle'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
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

// ── Add Subcategory Dialog ────────────────────────────────────────────────────

class _AddSubcategoryDialog extends StatefulWidget {
  final String categoryName;
  final Future<bool> Function(String name) onSave;

  const _AddSubcategoryDialog({
    required this.categoryName,
    required this.onSave,
  });

  @override
  State<_AddSubcategoryDialog> createState() =>
      _AddSubcategoryDialogState();
}

class _AddSubcategoryDialogState extends State<_AddSubcategoryDialog> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Alt kategori adı boş olamaz.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.onSave(name);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = 'Bu alt kategori zaten mevcut olabilir.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Alt Kategori Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ana Kategori: ',
                  style: TextStyle(
                      fontSize: 13, color: cs.onSurfaceVariant)),
              Text(
                widget.categoryName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            enabled: !_loading,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Alt Kategori Adı',
              hintText: 'Örn: Ejderha Meyvesi',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────

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
