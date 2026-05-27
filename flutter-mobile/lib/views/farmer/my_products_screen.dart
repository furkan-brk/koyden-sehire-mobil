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
          tabAlignment: TabAlignment.start,
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
            icon: Icons.inventory_2_outlined,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md + 80,
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
}

class _MyProductCard extends StatelessWidget {
  final FarmerProductModel product;
  const _MyProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        StatusBadge(kind: StatusBadge.fromString(product.status)),
                        if (product.status == 'active')
                          _StockBadge(stockStatus: product.stockStatus),
                      ],
                    ),
                  ],
                ),
              ),
              // Düzenle ikonu (sağ üst)
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: () =>
                    context.push('/farmer/products/${product.id}/edit'),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          // Admin notu
          if (product.adminNote != null && product.adminNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4, vertical: AppSpacing.sm),
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
                          fontSize: 12, color: AppColors.error, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stok durumu değiştir (sadece aktif ürünlerde)
          if (product.status == 'active') ...[
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
