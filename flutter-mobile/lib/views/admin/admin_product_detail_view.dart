import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_status_badge.dart';
import 'package:koyden_sehire/controllers/admin/admin_product_detail_controller.dart';

class AdminProductDetailView extends StatefulWidget {
  final String productId;
  const AdminProductDetailView({super.key, required this.productId});

  @override
  State<AdminProductDetailView> createState() =>
      _AdminProductDetailViewState();
}

class _AdminProductDetailViewState
    extends State<AdminProductDetailView> {
  late final AdminProductDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(
        AdminProductDetailController(repo, productId: widget.productId));
  }

  @override
  void dispose() {
    Get.delete<AdminProductDetailController>();
    super.dispose();
  }

  Future<void> _confirmModerate(String action) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approve' ? 'Ürünü Onayla' : 'Ürünü Reddet'),
        content: action == 'reject'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Reddetme sebebini yazın:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(hintText: 'Sebep...'),
                    maxLines: 2,
                  ),
                ],
              )
            : const Text('Bu ürünü onaylamak istiyor musunuz?'),
        actions: [
          AppButton(
            label: 'İptal',
            variant: AppButtonVariant.text,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: action == 'approve' ? 'Onayla' : 'Reddet',
            variant: action == 'approve'
                ? AppButtonVariant.primary
                : AppButtonVariant.destructive,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ).then((result) {
      reasonCtrl.dispose();
      return result;
    });
    if (confirmed == true && mounted) {
      final ok = await _ctrl.moderate(action,
          reason: action == 'reject' ? reasonCtrl.text : null);
      if (ok && mounted) {
        context.snack(
          action == 'approve' ? 'Ürün onaylandı.' : 'Ürün reddedildi.',
          isError: action == 'reject',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Obx(() {
          if (_ctrl.isLoading.value) return const AppLoading();
          if (_ctrl.error.value.isNotEmpty) {
            return AppErrorWidget(
                message: _ctrl.error.value, onRetry: _ctrl.load);
          }
          final product = _ctrl.product.value;
          if (product == null) return const SizedBox.shrink();

          if (isDesktop) return _buildDesktop(context, product);
          return _buildMobile(context, product);
        });
      },
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, dynamic product) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Breadcrumb + actions
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => context.go('/admin/products'),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Ürün Moderasyonu',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right,
                    size: 15, color: cs.outlineVariant),
              ),
              Expanded(
                child: Text(
                  product.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              AdminStatusBadge(status: product.status),
              if (product.status == 'pending') ...[
                const SizedBox(width: 12),
                if (_ctrl.isSubmitting.value)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => _confirmModerate('reject'),
                    icon: Icon(Icons.close, size: 15, color: cs.error),
                    label: Text('Reddet',
                        style:
                            TextStyle(color: cs.error, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _confirmModerate('approve'),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('Onayla',
                        style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        // 2-column content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: image gallery
                Expanded(
                  flex: 2,
                  child: _ImageGallery(imageUrls: product.imageUrls),
                ),
                const SizedBox(width: 20),
                // Right: product info
                Expanded(
                  flex: 3,
                  child: _ProductInfoCard(product: product, cs: cs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile ──────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context, dynamic product) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/products'),
        ),
        actions: (product.status == 'pending')
            ? [
                if (_ctrl.isSubmitting.value)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2)),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () => _confirmModerate('reject'),
                    icon: Icon(Icons.close, color: cs.error),
                    label: Text('Reddet',
                        style: TextStyle(color: cs.error)),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmModerate('approve'),
                    icon: Icon(Icons.check, color: cs.primary),
                    label: Text('Onayla',
                        style: TextStyle(color: cs.primary)),
                  ),
                ],
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrls.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: product.imageUrls.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrls[i],
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _ProductInfoCard(product: product, cs: cs),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ImageGallery extends StatelessWidget {
  final List<dynamic> imageUrls;
  const _ImageGallery({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  size: 36, color: AppColors.outlineVariant),
              SizedBox(height: 8),
              Text('Görsel yok',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: imageUrls.asMap().entries.map((e) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: e.key < imageUrls.length - 1 ? 8 : 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CachedNetworkImage(
              imageUrl: e.value as String,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  height: 200, color: AppColors.outlineVariant),
              errorWidget: (_, __, ___) => Container(
                height: 200,
                color: AppColors.outlineVariant,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProductInfoCard extends StatelessWidget {
  final dynamic product;
  final ColorScheme cs;
  const _ProductInfoCard({required this.product, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                AdminStatusBadge(status: product.status),
              ],
            ),
            const Divider(height: 24),
            _Row('Fiyat', '${product.price} ₺ / ${product.unit}'),
            _Row('Şehir', product.city),
            if (product.district != null)
              _Row('İlçe', product.district!),
            if (product.category != null)
              _Row('Kategori', product.category!.name),
            if (product.farmer != null) ...[
              _Row('Üretici', product.farmer!.displayName),
              if (product.farmer!.city != null)
                _Row('Üretici Şehri', product.farmer!.city!),
            ],
            if (product.description != null &&
                product.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Açıklama',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 6),
              Text(product.description!,
                  style: const TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
