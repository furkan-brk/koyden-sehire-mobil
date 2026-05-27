import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      Get.find<MyProductsController>().setStatus(_tabs[_tab.index].$2);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.products),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Ürünlerim'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farmer/products/new'),
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'Yeni Ürün',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Obx(() {
        final ctrl = Get.find<MyProductsController>();
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
          return RefreshIndicator(
            onRefresh: ctrl.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: _EmptyProductsState(
                    onAdd: () => context.push('/farmer/products/new'),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: ctrl.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MyProductCard(product: ctrl.items[i]),
          ),
        );
      }),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyProductsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_florist_outlined,
                size: 48,
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz ürün yok',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk ürününüzü ekleyerek müşterilerle\nbuluşmaya başlayın.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('İlk ürününüzü ekleyin'),
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductThumb(
                imageUrls: product.imageUrls,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.price(product.price, product.unit),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(status: product.status),
                        if (product.status == 'active')
                          _StockBadge(stockStatus: product.stockStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (product.adminNote != null && product.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      product.adminNote!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (product.status == 'active')
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      product.stockStatus == 'available'
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      product.stockStatus == 'available'
                          ? 'Mevcut'
                          : 'Tükendi',
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
              if (product.status == 'active') const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                  onPressed: () => context
                      .push('/farmer/products/${product.id}/edit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'active' => ('Aktif', AppColors.success, Icons.check_circle),
      'pending' => ('Beklemede', AppColors.warning, Icons.hourglass_bottom),
      'rejected' => ('Reddedildi', AppColors.error, Icons.cancel_outlined),
      'hidden' => ('Pasif', AppColors.onSurfaceVariant, Icons.visibility_off_outlined),
      _ => (status, AppColors.onSurfaceVariant, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
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
    final color = isAvailable ? AppColors.primaryContainer : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.inventory_2_outlined : Icons.remove_shopping_cart_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Stokta' : 'Tükendi',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final List<String> imageUrls;
  const _ProductThumb({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            width: 88,
            height: 88,
            child: imageUrls.isEmpty
                ? Container(
                    color: AppColors.surfaceContainerLow,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 32,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.surfaceContainerLow,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerLow,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ),
        if (imageUrls.length > 1)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
