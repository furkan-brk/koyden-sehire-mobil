import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/shared/widgets/location_filter_sheet.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/category_chip.dart';
import 'package:koyden_sehire/shared/widgets/farmer_mode_chip.dart';
import 'package:koyden_sehire/shared/widgets/product_card.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/shimmer_product_card.dart';
import 'package:koyden_sehire/models/category_model.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/controllers/public/product_list_controller.dart';

class ProductListScreen extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialSearch;

  const ProductListScreen({
    super.key,
    this.initialCategoryId,
    this.initialSearch,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  ProductListController get _ctrl => Get.find<ProductListController>();
  CategoryController get _catCtrl => Get.find<CategoryController>();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch ?? '';
    _searchController.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.applyFilter(
        ProductFilter(
          search: widget.initialSearch,
          categoryId: widget.initialCategoryId,
        ),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _ctrl.loadMore();
    }
  }

  void _showSortSheet() {
    final current = _ctrl.filter.value.sort;
    showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sıralama', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            _SortTile(
              label: 'En Yeni',
              value: null,
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, '__newest__'),
            ),
            _SortTile(
              label: 'Fiyat: Düşükten Yükseğe',
              value: 'price_asc',
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v),
            ),
            _SortTile(
              label: 'Fiyat: Yüksekten Düşüğe',
              value: 'price_desc',
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((value) {
      if (value == null) return;
      final filter = _ctrl.filter.value;
      _ctrl.applyFilter(
        value == '__newest__' ? filter.copyWith(clearSort: true) : filter.copyWith(sort: value),
      );
    });
  }

  void _onSearchSubmitted(String value) {
    final filter = _ctrl.filter.value;
    _ctrl.applyFilter(
      value.trim().isEmpty ? filter.copyWith(clearSearch: true) : filter.copyWith(search: value.trim()),
    );
  }

  Future<void> _showLocationFilterSheet() async {
    final current = _ctrl.filter.value;
    final result = await showLocationFilterSheet(
      context,
      initialCity: current.city,
      initialDistrict: current.district,
    );
    if (result == null) return;
    final f = _ctrl.filter.value;
    _ctrl.applyFilter(
      result.city == null
          ? f.copyWith(clearCity: true, clearDistrict: true)
          : f.copyWith(
              city: result.city,
              district: result.district ?? '',
              clearDistrict: result.district == null,
            ),
    );
  }

  void _selectCategory(String? id) {
    final filter = _ctrl.filter.value;
    _ctrl.applyFilter(
      id == null ? filter.copyWith(clearCategory: true) : filter.copyWith(categoryId: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürünler'),
        actions: const [FarmerModeChip()],
      ),
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.market),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm + 4,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              decoration: InputDecoration(
                hintText: 'Ürün veya üretici ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchSubmitted('');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Obx(() {
            final cats = _catCtrl.categories.where((c) => c.isRoot).toList();
            if (cats.isEmpty) return const SizedBox.shrink();
            return _CategoryFilterBar(
              categories: cats,
              selectedId: _ctrl.filter.value.categoryId,
              onSelect: _selectCategory,
            );
          }),
          Obx(() {
            final filter = _ctrl.filter.value;
            final hasLocation = filter.city?.isNotEmpty == true;
            final hasSort = filter.sort != null;
            final sortLabel = switch (filter.sort) {
              'price_asc' => 'Ucuzdan Pahalıya',
              'price_desc' => 'Pahalıdan Ucuza',
              _ => 'Sırala',
            };
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 4),
              child: Row(
                children: [
                  _LocationFilterChip(
                    city: filter.city,
                    district: filter.district,
                    onTap: _showLocationFilterSheet,
                    onClear: hasLocation
                        ? () => _ctrl.applyFilter(
                              filter.copyWith(clearCity: true, clearDistrict: true),
                            )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _SortChip(
                    label: sortLabel,
                    isActive: hasSort,
                    onTap: _showSortSheet,
                    onClear: hasSort
                        ? () => _ctrl.applyFilter(filter.copyWith(clearSort: true))
                        : null,
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            final ctrl = _ctrl;
            final cs = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: ctrl.isLoading.value
                  ? Text('Yükleniyor...', style: TextStyle(color: cs.onSurfaceVariant))
                  : RichText(
                      text: TextSpan(
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: '${ctrl.total.value}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const TextSpan(text: ' ürün listeleniyor'),
                        ],
                      ),
                    ),
            );
          }),
          Expanded(
            child: Obx(() => _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final ctrl = _ctrl;
    if (ctrl.isLoading.value && ctrl.items.isEmpty) {
      return const ShimmerList();
    }
    if (ctrl.errorMessage.value != null && ctrl.items.isEmpty) {
      return AppErrorWidget(
        message: ctrl.errorMessage.value!,
        onRetry: ctrl.refresh,
      );
    }
    if (ctrl.items.isEmpty) {
      final f = ctrl.filter.value;
      String emptyMsg;
      if (f.search?.isNotEmpty ?? false) {
        emptyMsg = '"${f.search}" için sonuç bulunamadı';
      } else if (f.city?.isNotEmpty ?? false) {
        final loc = (f.district?.isNotEmpty ?? false) ? '${f.city} / ${f.district}' : f.city!;
        emptyMsg = '$loc konumunda henüz ürün bulunmuyor';
      } else {
        emptyMsg = 'Henüz ürün bulunmuyor';
      }
      return AppEmptyWidget(message: emptyMsg);
    }
    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: ctrl.items.length + (ctrl.isLoadingMore.value ? 2 : 0),
        itemBuilder: (_, i) {
          if (i >= ctrl.items.length) {
            return const ShimmerProductCard();
          }
          return ProductCard(product: ctrl.items[i]);
        },
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _CategoryFilterBar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return AppCategoryChip(
              label: 'Tümü',
              selected: selectedId == null,
              onTap: () => onSelect(null),
            );
          }
          final c = categories[i - 1];
          return AppCategoryChip(
            label: c.name,
            selected: c.id == selectedId,
            onTap: () => onSelect(c.id),
          );
        },
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const _SortTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String?>(
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}

class _LocationFilterChip extends StatelessWidget {
  final String? city;
  final String? district;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _LocationFilterChip({
    required this.city,
    required this.district,
    required this.onTap,
    required this.onClear,
  });

  String get _label {
    if (city == null || city!.isEmpty) return 'Konum';
    if (district != null && district!.isNotEmpty) return '$city / $district';
    return city!;
  }

  bool get _isActive => city != null && city!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _isActive ? AppColors.primaryFixed : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: _isActive ? AppColors.primaryContainer : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 15,
              color: _isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
                color: _isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            if (_isActive && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _SortChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryFixed : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive ? AppColors.primaryContainer : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort,
              size: 15,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            if (isActive && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
