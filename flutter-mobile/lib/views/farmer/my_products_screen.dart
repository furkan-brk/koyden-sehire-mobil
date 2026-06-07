import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/utils/confirm_dialog.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/search_field.dart';
import 'package:koyden_sehire/shared/widgets/status_badge.dart';
import 'package:koyden_sehire/models/farmer_product_model.dart';
import 'package:koyden_sehire/controllers/farmer/my_products_controller.dart';

const _tabs = [
  ('Tümü', null),
  ('Aktif', 'active'),
  ('Beklemede', 'pending'),
  ('Pasif', 'hidden'),
  ('Reddedildi', 'rejected'),
];

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      Get.find<MyProductsController>().setStatus(_tabs[_tab.index].$2);
    });
    final ctrl = Get.find<MyProductsController>();
    _searchCtrl = TextEditingController(text: ctrl.searchQuery.value);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<MyProductsController>();

    return Scaffold(
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.products),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Obx(() => Text(
              ctrl.selectionMode.value
                  ? '${ctrl.selectedIds.length} seçili'
                  : 'Ürünlerim',
            )),
        actions: [
          Obx(() {
            final inSelection = ctrl.selectionMode.value;
            return TextButton.icon(
              onPressed: ctrl.toggleSelectionMode,
              icon: Icon(
                inSelection ? Icons.close : Icons.checklist_rtl,
                size: 18,
              ),
              label: Text(inSelection ? 'Vazgeç' : 'Seç'),
            );
          }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: SearchField(
                  controller: _searchCtrl,
                  hintText: 'Ürünlerim arasında ara',
                  onChanged: ctrl.setSearchQuery,
                  onClear: () => ctrl.setSearchQuery(''),
                ),
              ),
              TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Obx(() {
        if (ctrl.selectionMode.value) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => context.push('/farmer/products/new'),
          icon: const Icon(Icons.add),
          label: const Text('Yeni Ürün'),
        );
      }),
      bottomSheet: Obx(() {
        if (!ctrl.selectionMode.value) return const SizedBox.shrink();
        final count = ctrl.selectedIds.length;
        return _BulkActionBar(
          count: count,
          busy: ctrl.bulkBusy.value,
          onPassivate: count == 0
              ? null
              : () => _confirmAndBulkPassivate(context, ctrl, count),
        );
      }),
      body: Obx(() {
        if (ctrl.isLoading.value && ctrl.items.isEmpty) {
          return const AppLoading();
        }
        if (ctrl.errorMessage.value != null && ctrl.items.isEmpty) {
          return AppErrorWidget(
            message: ctrl.errorMessage.value!,
            onRetry: ctrl.refresh,
          );
        }
        if (ctrl.items.isEmpty) {
          // Distinguish "no products at all" from "search matches nothing".
          final isFilteredOut =
              ctrl.searchQuery.value.trim().isNotEmpty;
          return AppEmptyWidget(
            icon: isFilteredOut
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            message: isFilteredOut
                ? 'Arama sonucu bulunamadı.'
                : 'Henüz ürün eklemediniz.',
            action: isFilteredOut
                ? TextButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      ctrl.setSearchQuery('');
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Aramayı temizle'),
                  )
                : TextButton.icon(
                    onPressed: () => context.push('/farmer/products/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk ürününüzü ekleyin'),
                  ),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md + (ctrl.selectionMode.value ? 100 : 80),
            ),
            itemCount: ctrl.items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm + 4),
            itemBuilder: (_, i) => _MyProductCard(product: ctrl.items[i]),
          ),
        );
      }),
    );
  }

  Future<void> _confirmAndBulkPassivate(
    BuildContext context,
    MyProductsController ctrl,
    int count,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Seçilenleri pasifleştir',
      message: '$count ürün pasif duruma alınacak. Onaylıyor musunuz?',
      confirmLabel: 'Pasifleştir',
      isDestructive: true,
    );
    if (!ok) return;
    final updated = await ctrl.bulkPassivateSelected();
    if (!context.mounted) return;
    context.toast('$updated ürün pasifleştirildi');
  }
}

class _BulkActionBar extends StatelessWidget {
  final int count;
  final bool busy;
  final VoidCallback? onPassivate;
  const _BulkActionBar({
    required this.count,
    required this.busy,
    required this.onPassivate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        color: cs.surfaceContainerHighest,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(Icons.check_box_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count ürün seçildi',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: busy ? null : onPassivate,
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Pasifleştir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyProductCard extends StatelessWidget {
  final FarmerProductModel product;
  const _MyProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ctrl = Get.find<MyProductsController>();

    return Obx(() {
      final inSelection = ctrl.selectionMode.value;
      final selected = ctrl.isSelected(product.id);

      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: inSelection ? () => ctrl.toggleSelected(product.id) : null,
        onLongPress: inSelection
            ? null
            : () {
                ctrl.enterSelectionMode();
                ctrl.toggleSelected(product.id);
              },
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.25)
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: selected
                ? Border.all(color: cs.primary, width: 1.5)
                : null,
            boxShadow: selected ? null : AppShadows.soft,
          ),
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inSelection)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => ctrl.toggleSelected(product.id),
                      ),
                    ),
                  // Ürün görseli
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: product.imageUrls.isEmpty
                          ? Container(
                              color: cs.surfaceContainerLow,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image_outlined,
                                color: cs.onSurfaceVariant,
                                size: 28,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: product.imageUrls.first,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: cs.surfaceContainer,
                                highlightColor: cs.surfaceContainerLow,
                                child: Container(
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: cs.surfaceContainerLow,
                                alignment: Alignment.center,
                                child: Icon(Icons.broken_image_outlined,
                                    color: cs.onSurfaceVariant),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  // Ürün bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppFormatters.price(product.price, product.unit),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StatusBadge(
                                kind: StatusBadge.fromString(product.status)),
                            if (product.status == 'active')
                              _StockBadge(stockStatus: product.stockStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Düzenle / Sil ikonları
                  if (!inSelection) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Column(
                      children: [
                        _IconBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Düzenle',
                          onTap: () => context
                              .push('/farmer/products/${product.id}/edit'),
                        ),
                        const SizedBox(height: 6),
                        _IconBtn(
                          icon: Icons.delete_outline,
                          tooltip: 'Sil',
                          danger: true,
                          onTap: () => _confirmAndDelete(context, ctrl),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // Admin notu
              if (product.adminNote != null &&
                  product.adminNote!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4,
                      vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 15, color: AppColors.error),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(
                        child: Text(
                          product.adminNote!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Stok durumu değiştir (sadece aktif ürünlerde, seçim modunda gizli)
              if (product.status == 'active' && !inSelection) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(
                      product.stockStatus == 'available'
                          ? Icons.remove_circle_outline
                          : Icons.check_circle_outline,
                      size: 17,
                    ),
                    label: Text(
                      product.stockStatus == 'available'
                          ? 'Tükendi Olarak İşaretle'
                          : 'Mevcut Olarak İşaretle',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      final next = product.stockStatus == 'available'
                          ? 'out_of_stock'
                          : 'available';
                      final ok = await Get.find<MyProductsController>()
                          .setStockStatus(product.id, next);
                      if (!context.mounted) return;
                      if (ok) context.toast('Stok durumu güncellendi');
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    MyProductsController ctrl,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Ürünü sil',
      message:
          '"${product.title}" ürünü kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      confirmLabel: 'Sil',
      isDestructive: true,
    );
    if (!ok) return;
    final err = await ctrl.deleteProduct(product.id);
    if (!context.mounted) return;
    if (err == null) {
      context.toast('Ürün silindi');
    } else {
      context.snack(err, isError: true);
    }
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: danger
                ? AppColors.error.withValues(alpha: 0.08)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: danger ? AppColors.error : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String stockStatus;
  const _StockBadge({required this.stockStatus});

  @override
  Widget build(BuildContext context) {
    final isAvailable = stockStatus == 'available';
    final color =
        isAvailable ? AppColors.success : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isAvailable ? 'Stokta Var' : 'Tükendi',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
