import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool compact;

  const ProductCard({super.key, required this.product, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/products/${product.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(product: product),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                    if (product.farmer != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              product.farmer!.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppFormatters.price(product.price, product.unit),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${product.city}, ${product.district}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _StockBadge(stockStatus: product.stockStatus),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final ProductModel product;
  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (product.firstImage == null)
              Container(
                color: cs.surfaceContainerLow,
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: cs.onSurfaceVariant,
                  size: 32,
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: product.firstImage!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: cs.surfaceContainerLow),
                errorWidget: (_, __, ___) => Container(
                  color: cs.surfaceContainerLow,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            // Top-left category/organic badge
            if (product.categoryName != null)
              Positioned(
                top: 8,
                left: 8,
                child: _CompactPillBadge(
                  label: product.categoryName!,
                  bg: AppColors.secondaryContainer,
                  fg: AppColors.secondary,
                ),
              ),
            // Top-right favorite toggle
            Positioned(
              top: 6,
              right: 6,
              child: Obx(() {
                final favs = Get.find<FavoritesService>();
                final isFav = favs.isFavorite(product.id);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => favs.toggle(context, product.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPillBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _CompactPillBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.1,
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
    final available = stockStatus == 'available';
    final limited = stockStatus == 'limited';
    final Color bg;
    final Color fg;
    final String label;
    if (available) {
      bg = AppColors.secondaryContainer;
      fg = AppColors.secondary;
      label = 'Mevcut';
    } else if (limited) {
      bg = const Color(0xFFFCE8C6);
      fg = const Color(0xFF7A5A18);
      label = 'Sınırlı';
    } else {
      bg = const Color(0xFFE5E7E6);
      fg = AppColors.onSurfaceVariant;
      label = 'Tükendi';
    }
    return _CompactPillBadge(label: label, bg: bg, fg: fg);
  }
}
