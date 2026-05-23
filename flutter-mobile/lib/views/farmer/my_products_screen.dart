import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
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
        icon: const Icon(Icons.add),
        label: const Text('Yeni Ürün'),
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
          return AppEmptyWidget(
            message: 'Henüz ürün eklemediniz.',
            action: TextButton.icon(
              onPressed: () => context.push('/farmer/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('İlk ürününüzü ekleyin'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MyProductCard(product: ctrl.items[i]),
          ),
        );
      }),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: product.imageUrls.isEmpty
                      ? Container(
                          color: AppColors.surfaceContainerLow,
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.onSurfaceVariant),
                        )
                      : CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      AppFormatters.price(product.price, product.unit),
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(status: product.status),
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
    final (label, color) = switch (status) {
      'active' => ('Aktif', AppColors.success),
      'pending' => ('Beklemede', AppColors.warning),
      'rejected' => ('Reddedildi', AppColors.error),
      'hidden' => ('Pasif', AppColors.onSurfaceVariant),
      _ => (status, AppColors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
