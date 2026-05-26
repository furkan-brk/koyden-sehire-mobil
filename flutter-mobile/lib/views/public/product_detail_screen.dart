import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/farmer_mode_chip.dart';
import 'package:koyden_sehire/shared/widgets/founding_badge.dart';
import 'package:koyden_sehire/shared/widgets/image_carousel.dart';
import 'package:koyden_sehire/shared/widgets/verified_badge.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/services/product_repository.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/controllers/public/product_detail_controller.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      ProductDetailController(
        Get.find<ProductRepository>(),
        productId: widget.productId,
      ),
      tag: widget.productId,
    );
  }

  @override
  void dispose() {
    Get.delete<ProductDetailController>(tag: widget.productId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Detayı'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Obx(() {
            final favs = Get.find<FavoritesService>();
            final isFav = favs.isFavorite(widget.productId);
            return IconButton(
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AppColors.error : null,
              ),
              tooltip: isFav ? 'Favorilerden çıkar' : 'Favorilere ekle',
              onPressed: () => favs.toggle(context, widget.productId),
            );
          }),
          const FarmerModeChip(),
        ],
      ),
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.market),
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.product.value == null) {
          return const AppLoading();
        }
        if (_ctrl.error.value != null && _ctrl.product.value == null) {
          return AppErrorWidget(
            message: _ctrl.error.value!,
            onRetry: _ctrl.load,
          );
        }
        final product = _ctrl.product.value;
        if (product == null) return const AppLoading();
        return _Body(product: product);
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final ProductModel product;

  const _Body({required this.product});

  @override
  Widget build(BuildContext context) {
    final farmer = product.farmer;
    final cs = Theme.of(context).colorScheme;
    final locationText = [
      product.city,
      product.district,
      if (product.village != null) product.village,
    ].whereType<String>().join(', ');
    return ListView(
      children: [
        ImageCarousel(imageUrls: product.imageUrls),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.title, style: context.text.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppFormatters.price(product.price, product.unit),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: cs.primaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              if (product.categoryName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    product.categoryName!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md - 4),
              Row(
                children: [
                  _StockChip(stockStatus: product.stockStatus),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            locationText,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text('Açıklama', style: context.text.titleMedium),
              const SizedBox(height: 8),
              Text(product.description, style: const TextStyle(height: 1.5)),
              if (farmer != null) ...[
                const SizedBox(height: 24),
                _FarmerCard(farmer: farmer),
              ],
              const SizedBox(height: 16),
              if (product.isAvailable && farmer != null)
                AppButton(
                  label: 'Üreticiyi Gör ve İletişime Geç',
                  icon: const Icon(Icons.person_outline, color: Colors.white),
                  onPressed: () => context.push('/farmers/${farmer.id}'),
                )
              else if (!product.isAvailable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Text(
                    'Bu ürün şu an tükenmiş.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md - 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aracısız. Komisyonsuz. Doğrudan üreticiden.',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.primaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    const Text(
                      AppConstants.platformInfoText,
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Uygunsuz İçerik Bildir'),
                  onPressed: () {
                    context.toast('Bildirim alındı. Ekibimiz inceleyecek.');
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockChip extends StatelessWidget {
  final String stockStatus;
  const _StockChip({required this.stockStatus});
  @override
  Widget build(BuildContext context) {
    final available = stockStatus == 'available';
    final color = available ? AppColors.success : AppColors.onSurfaceVariant;
    final label = available
        ? 'Mevcut'
        : (stockStatus == 'limited' ? 'Sınırlı' : 'Tükendi');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final FarmerSummary farmer;
  const _FarmerCard({required this.farmer});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/farmers/${farmer.id}'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md - 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surfaceContainerLow,
              backgroundImage: farmer.profileImageUrl == null
                  ? null
                  : NetworkImage(farmer.profileImageUrl!),
              child: farmer.profileImageUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farmer.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${farmer.city}, ${farmer.district}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (farmer.isFoundingFarmer) const FoundingBadge(),
                      if (farmer.isVerified) const VerifiedBadge(),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
