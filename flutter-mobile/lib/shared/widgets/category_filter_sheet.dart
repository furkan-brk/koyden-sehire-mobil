import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/models/category_model.dart';

/// Sentinel returned by [CategoryFilterSheet] to signal the filter should be
/// cleared entirely (as opposed to `null`, which means the sheet was dismissed
/// without a decision).
const String kCategoryFilterClear = '__clear__';

/// Opens the two-column category filter bottom sheet.
///
/// Returns:
/// * a category id (root or child) when the user taps **Uygula**,
/// * [kCategoryFilterClear] when the user taps **Filtreyi Temizle**,
/// * `null` when the sheet is dismissed without applying.
Future<String?> showCategoryFilterSheet(
  BuildContext context, {
  String? initialCategoryId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CategoryFilterSheet(initialCategoryId: initialCategoryId),
  );
}

class CategoryFilterSheet extends StatefulWidget {
  final String? initialCategoryId;

  const CategoryFilterSheet({super.key, this.initialCategoryId});

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  final CategoryController _catCtrl = Get.find<CategoryController>();

  /// Root category whose children are shown in the right column.
  String? _activeRootId;

  /// Currently selected category id (a root id means "all of that root",
  /// a child id means that specific subcategory). `null` = nothing selected.
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialCategoryId;
    _activeRootId = _resolveRootId(widget.initialCategoryId);
  }

  List<CategoryModel> get _roots =>
      _catCtrl.categories.where((c) => c.isRoot).toList();

  /// Resolves which root should be highlighted for a given selected id.
  /// Falls back to the first root when the id is null or unresolvable.
  String? _resolveRootId(String? selectedId) {
    final roots = _roots;
    if (roots.isEmpty) return null;
    if (selectedId != null) {
      for (final root in roots) {
        if (root.id == selectedId) return root.id;
        if (root.children.any((c) => c.id == selectedId)) return root.id;
      }
    }
    return roots.first.id;
  }

  CategoryModel? get _activeRoot {
    for (final r in _roots) {
      if (r.id == _activeRootId) return r;
    }
    return _roots.isEmpty ? null : _roots.first;
  }

  void _onApply() {
    Navigator.pop(context, _selectedId ?? kCategoryFilterClear);
  }

  void _onClear() {
    Navigator.pop(context, kCategoryFilterClear);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.68;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Obx(() {
        if (_catCtrl.isLoading.value && _catCtrl.categories.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            const Divider(height: 1, color: AppColors.outlineVariant),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRootColumn(),
                  Expanded(child: _buildChildColumn()),
                ],
              ),
            ),
            _buildFooter(),
          ],
        );
      }),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm + 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.outlineVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Text(
            'Kategori',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRootColumn() {
    final roots = _roots;
    return Container(
      // Dar ekranlarda sidebar, sheet genişliğinin %40'ını geçmez.
      width: math.min(148.0, MediaQuery.sizeOf(context).width * 0.4),
      color: AppColors.surfaceContainerLow,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: roots.length,
        itemBuilder: (_, i) {
          final root = roots[i];
          final isActive = root.id == _activeRootId;
          return InkWell(
            onTap: () => setState(() => _activeRootId = root.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.surfaceContainerLowest
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isActive ? AppColors.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                root.name,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChildColumn() {
    final root = _activeRoot;
    if (root == null) return const SizedBox.shrink();

    // "Tümü" (whole root) followed by each subcategory.
    final tiles = <Widget>[
      _ChildTile(
        label: 'Tümü (${root.name})',
        selected: _selectedId == root.id,
        onTap: () => setState(() => _selectedId = root.id),
      ),
      for (final child in root.children)
        _ChildTile(
          label: child.name,
          selected: _selectedId == child.id,
          onTap: () => setState(() => _selectedId = child.id),
        ),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: ListView(
        key: ValueKey(root.id),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        children: tiles,
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _onClear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text('Filtreyi Temizle'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: FilledButton(
                onPressed: _onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text('Uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChildTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  size: 20, color: AppColors.primary)
            else
              const Icon(Icons.circle_outlined,
                  size: 20, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
