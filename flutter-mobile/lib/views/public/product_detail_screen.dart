import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/core/utils/whatsapp_helper.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/fullscreen_photo_viewer.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/services/product_repository.dart';
import 'package:koyden_sehire/services/report_repository.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/controllers/public/product_detail_controller.dart';
import 'package:koyden_sehire/core/services/recent_views_service.dart';

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
    ever<ProductModel?>(_ctrl.product, (p) {
      if (p != null) {
        Get.find<RecentViewsService>().addProduct(
          id: p.id,
          title: p.title,
          imageUrl: p.imageUrls.isNotEmpty ? p.imageUrls.first : null,
        );
      }
    });
  }

  @override
  void dispose() {
    Get.delete<ProductDetailController>(tag: widget.productId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
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
                color: isFav ? AppColors.error : AppColors.onSurface,
              ),
              tooltip: isFav ? 'Favorilerden çıkar' : 'Favorilere ekle',
              onPressed: () => favs.toggle(context, widget.productId),
            );
          }),
          Obx(() {
            final product = _ctrl.product.value;
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Diğer',
              onSelected: (v) {
                if (v == 'share' && product != null) {
                  Share.share(
                    '${product.title} - Köyden Şehire\n'
                    'https://koydensehire.com/products/${product.id}',
                  );
                } else if (v == 'report') {
                  _showReportDialog(context, widget.productId);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.share_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Paylaş'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.flag_outlined, size: 18),
                    SizedBox(width: 12),
                    Text('Şikayet et'),
                  ]),
                ),
              ],
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: CustomerBottomNav(current: CustomerTab.market),
      ),
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
    final locationText = [
      product.city,
      product.district,
      if (product.village != null && product.village!.isNotEmpty) product.village,
    ].whereType<String>().join(', ');

    final hasDescription = product.description.trim().isNotEmpty;
    return ListView(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      children: [
        _HeroImage(product: product),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _TitlePriceRow(
            product: product,
            locationText: locationText,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (farmer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _FarmerStoryCard(
              farmer: farmer,
              product: product,
            ),
          ),
        if (hasDescription) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _DescriptionBlock(description: product.description),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  final ProductModel product;
  const _HeroImage({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final images = product.imageUrls;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.xl),
        bottomRight: Radius.circular(AppRadius.xl),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              Container(
                color: cs.surfaceContainerLow,
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              GestureDetector(
                onTap: () => showFullscreenPhotoViewer(
                  context,
                  imageUrls: images,
                  initialIndex: 0,
                ),
                child: CachedNetworkImage(
                  imageUrl: images.first,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: cs.surfaceContainer,
                    highlightColor: cs.surfaceContainerLow,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: cs.surfaceContainerLow,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (images.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TitlePriceRow extends StatelessWidget {
  final ProductModel product;
  final String locationText;

  const _TitlePriceRow({required this.product, required this.locationText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = product.isAvailable;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
              ),
              if (locationText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  locationText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₺${_formatPrice(product.price)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: available ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            if (product.unit.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                product.unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
            if (!available) ...[
              const SizedBox(height: 6),
              Text(
                product.isOutOfStock ? 'Şu an tükendi' : 'Sınırlı stok',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatPrice(num v) {
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    // 1234 -> 1.234 (tr grouping)
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    return parts.length > 1 ? '${buf.toString()},${parts[1]}' : buf.toString();
  }
}

class _DescriptionBlock extends StatelessWidget {
  final String description;
  const _DescriptionBlock({required this.description});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Ürün Hikayesi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _FarmerStoryCard extends StatelessWidget {
  final FarmerSummary farmer;
  final ProductModel product;

  const _FarmerStoryCard({required this.farmer, required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final producerLabel = producerTypeLabel(farmer.producerType);
    final farmerLocation = [
      farmer.city,
      farmer.district,
      if (farmer.village != null && farmer.village!.isNotEmpty) farmer.village,
    ].whereType<String>().join(', ');

    final subtitleParts = <String>[
      producerLabel,
      if (farmerLocation.isNotEmpty) farmerLocation,
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/farmers/${farmer.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FarmerAvatar(farmer: farmer),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                farmer.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (farmer.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified,
                                size: 14,
                                color: cs.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              _ContactButton(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmerAvatar extends StatelessWidget {
  final FarmerSummary farmer;
  const _FarmerAvatar({required this.farmer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = farmer.profileImageUrl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerLowest,
        border: Border.all(color: cs.surface, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(Icons.person, color: cs.onSurfaceVariant)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Icon(
                Icons.person,
                color: cs.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final ProductModel product;
  const _ContactButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final phone = product.publicPhone;
    final farmer = product.farmer;
    final available = product.isAvailable;
    final canWhatsApp = phone != null && phone.isNotEmpty && available;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: !available
            ? null
            : () async {
                if (canWhatsApp) {
                  final msg =
                      'Merhaba, "${product.title}" ilanınız için bilgi almak istiyorum. (Köyden Şehire)';
                  final ok = await WhatsAppHelper.open(phone, msg);
                  if (!ok && context.mounted && farmer != null) {
                    context.push('/farmers/${farmer.id}');
                  }
                } else if (farmer != null) {
                  context.push('/farmers/${farmer.id}');
                }
              },
        icon: Icon(
          canWhatsApp ? Icons.chat_bubble_outline : Icons.person_outline,
          size: 18,
        ),
        label: Text(
          !available
              ? 'Şu an tükendi'
              : (canWhatsApp
                  ? 'Üreticiye Mesaj Gönder'
                  : 'Üretici Profilini Gör'),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.surfaceContainerHigh,
          disabledForegroundColor: cs.onSurfaceVariant,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Future<void> _showReportDialog(BuildContext context, String productId) async {
  const reasons = <({String key, String label})>[
    (key: 'inappropriate', label: 'Uygunsuz içerik'),
    (key: 'misleading', label: 'Yanıltıcı bilgi'),
    (key: 'spam', label: 'Spam'),
    (key: 'other', label: 'Diğer'),
  ];

  String? selectedKey;
  final noteCtrl = TextEditingController();
  bool submitting = false;

  await Get.dialog<void>(
    StatefulBuilder(
      builder: (ctx, setState) {
        final isOther = selectedKey == 'other';
        return AlertDialog(
          title: const Text('Uygunsuz İçerik Bildir'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bu içeriği neden bildirmek istiyorsunuz?',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: selectedKey,
                  onChanged: (v) => setState(() => selectedKey = v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in reasons)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: r.key,
                          title: Text(r.label),
                        ),
                    ],
                  ),
                ),
                if (isOther) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText: 'Lütfen kısaca açıklayın',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Get.back(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: submitting || selectedKey == null
                  ? null
                  : () async {
                      if (selectedKey == 'other' &&
                          noteCtrl.text.trim().isEmpty) {
                        ctx.snack('Lütfen bir açıklama girin', isError: true);
                        return;
                      }
                      setState(() => submitting = true);
                      try {
                        await Get.find<ReportRepository>().submitReport(
                          targetType: 'product',
                          targetId: productId,
                          reason: selectedKey!,
                          note: noteCtrl.text.trim(),
                        );
                        if (Get.isDialogOpen ?? false) Get.back();
                        if (context.mounted) {
                          context.snack(
                            'Bildiriminiz alındı, inceleyeceğiz',
                          );
                        }
                      } catch (_) {
                        setState(() => submitting = false);
                        if (context.mounted) {
                          context.snack(
                            'Bildirim gönderilemedi. Lütfen tekrar deneyin.',
                            isError: true,
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gönder'),
            ),
          ],
        );
      },
    ),
    barrierDismissible: true,
  );

  noteCtrl.dispose();
}
