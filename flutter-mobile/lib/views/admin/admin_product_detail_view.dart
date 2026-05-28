import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

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
  State<AdminProductDetailView> createState() => _AdminProductDetailViewState();
}

class _AdminProductDetailViewState extends State<AdminProductDetailView> {
  late final AdminProductDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminProductDetailController(repo, productId: widget.productId));
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
            variant: action == 'approve' ? AppButtonVariant.primary : AppButtonVariant.destructive,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text; // dispose öncesi yakala
    reasonCtrl.dispose();
    if (confirmed == true && mounted) {
      final ok = await _ctrl.moderate(action, reason: action == 'reject' ? reason : null);
      if (ok && mounted) {
        context.snack(action == 'approve' ? 'Ürün onaylandı.' : 'Ürün reddedildi.', isError: action == 'reject');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const AppLoading();
      }
      if (_ctrl.error.value.isNotEmpty) {
        return AppErrorWidget(
          message: _ctrl.error.value,
          onRetry: _ctrl.load,
        );
      }

      final product = _ctrl.product.value;
      if (product == null) return const SizedBox.shrink();

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
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed: () => _confirmModerate('reject'),
                      icon: Icon(Icons.close, color: cs.error),
                      label: Text('Reddet', style: TextStyle(color: cs.error)),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmModerate('approve'),
                      icon: Icon(Icons.check, color: cs.primary),
                      label: Text('Onayla', style: TextStyle(color: cs.primary)),
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
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          AdminStatusBadge(status: product.status),
                        ],
                      ),
                      const Divider(height: 20),
                      _Row('Fiyat', '${product.price} ₺ / ${product.unit}'),
                      _Row('Şehir', product.city),
                      if (product.district != null) _Row('İlçe', product.district!),
                      if (product.category != null) _Row('Kategori', product.category!.name),
                      if (product.farmer != null) ...[
                        _Row('Üretici', product.farmer!.displayName),
                        if (product.farmer!.city != null) _Row('Üretici Şehri', product.farmer!.city!),
                      ],
                      if (product.description != null && product.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Açıklama',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(product.description!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
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
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
