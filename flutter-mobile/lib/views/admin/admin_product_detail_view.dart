import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final title = switch (action) {
      'approve' => 'Ürünü Onayla',
      'reject' => 'Ürünü Reddet',
      'hide' => 'Ürünü Yayından Kaldır',
      _ => 'Ürün',
    };
    final confirmLabel = switch (action) {
      'approve' => 'Onayla',
      'reject' => 'Reddet',
      'hide' => 'Yayından Kaldır',
      _ => 'Onayla',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
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
            : Text(action == 'approve'
                ? 'Bu ürünü onaylamak istiyor musunuz?'
                : 'Bu ürünü yayından kaldırmak istiyor musunuz? Ürün listelerde görünmeyecek.'),
        actions: [
          AppButton(
            label: 'İptal',
            variant: AppButtonVariant.text,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: confirmLabel,
            variant: action == 'approve'
                ? AppButtonVariant.primary
                : AppButtonVariant.destructive,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (confirmed == true && mounted) {
      final ok = await _ctrl.moderate(action, reason: action == 'reject' ? reason : null);
      if (ok && mounted) {
        final successMsg = switch (action) {
          'approve' => 'Ürün onaylandı.',
          'reject' => 'Ürün reddedildi.',
          'hide' => 'Ürün yayından kaldırıldı.',
          _ => 'İşlem tamamlandı.',
        };
        context.snack(
          successMsg,
          isError: action != 'approve',
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
              ] else if (product.status == 'active') ...[
                const SizedBox(width: 12),
                if (_ctrl.isSubmitting.value)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _confirmModerate('hide'),
                    icon: Icon(Icons.visibility_off_outlined,
                        size: 15, color: cs.error),
                    label: Text('Yayından Kaldır',
                        style:
                            TextStyle(color: cs.error, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
              ] else if (product.status == 'hidden') ...[
                const SizedBox(width: 12),
                if (_ctrl.isSubmitting.value)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _confirmModerate('approve'),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Yayına Al',
                        style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
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
                // Right: product info + farmer card
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProductInfoCard(product: product, cs: cs),
                      if (product.farmer != null) ...[
                        const SizedBox(height: 16),
                        _FarmerCard(
                          farmer: product.farmer!,
                          cs: cs,
                          onNavigate: () => context.go(
                              '/admin/farmers/${product.farmer!.id}'),
                        ),
                      ],
                    ],
                  ),
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
            : (product.status == 'active')
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
                    else
                      TextButton.icon(
                        onPressed: () => _confirmModerate('hide'),
                        icon: Icon(Icons.visibility_off_outlined,
                            color: cs.error),
                        label: Text('Yayından Kaldır',
                            style: TextStyle(color: cs.error)),
                      ),
                  ]
                : (product.status == 'hidden')
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
                        else
                          TextButton.icon(
                            onPressed: () => _confirmModerate('approve'),
                            icon: Icon(Icons.visibility_outlined,
                                color: cs.primary),
                            label: Text('Yayına Al',
                                style: TextStyle(color: cs.primary)),
                          ),
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
            if (product.farmer != null) ...[
              const SizedBox(height: 12),
              _FarmerCard(
                farmer: product.farmer!,
                cs: cs,
                onNavigate: () => context
                    .go('/admin/farmers/${product.farmer!.id}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ImageGallery extends StatefulWidget {
  final List<dynamic> imageUrls;
  const _ImageGallery({required this.imageUrls});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls;
    if (images.isEmpty) {
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

    // Guard against a stale index if the image list shrank.
    final selected = _selectedIndex.clamp(0, images.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Large selected image ─────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: CachedNetworkImage(
            imageUrl: images[selected] as String,
            width: double.infinity,
            height: 360,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(height: 360, color: AppColors.outlineVariant),
            errorWidget: (_, __, ___) => Container(
              height: 360,
              color: AppColors.outlineVariant,
              child: const Icon(Icons.broken_image_outlined,
                  color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        // ── Horizontal thumbnails ────────────────────────────────
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: images.asMap().entries.map((e) {
                final isSelected = e.key == selected;
                return Padding(
                  padding: EdgeInsets.only(
                      right: e.key < images.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = e.key),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.outlineVariant,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: e.value as String,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.outlineVariant),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.outlineVariant,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 18,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
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
            _Row('Fiyat', '${product.price} ₺ / ${product.unit}', cs),
            _Row('Şehir', product.city, cs),
            if (product.district != null && product.district!.isNotEmpty)
              _Row('İlçe', product.district!, cs),
            if (product.village != null && product.village!.isNotEmpty)
              _Row('Köy / Mahalle', product.village!, cs),
            if (product.category != null)
              _Row(
                  'Kategori',
                  product.category!.parentName != null
                      ? '${product.category!.parentName} › ${product.category!.name}'
                      : product.category!.name,
                  cs),
            if (product.stockStatus != null && product.stockStatus!.isNotEmpty)
              _Row('Stok Durumu', _stockLabel(product.stockStatus!), cs),
            if (product.publishedAt != null && product.status == 'active')
              _Row(
                  'Onaylandığı Tarih',
                  DateFormat('d MMMM y, HH:mm', 'tr_TR')
                      .format(product.publishedAt!.toLocal()),
                  cs),
            if (product.rejectionReason != null &&
                product.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Red Sebebi',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 4),
                    Text(product.rejectionReason!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
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

  String _stockLabel(String s) {
    switch (s) {
      case 'in_stock':
        return 'Stokta var';
      case 'out_of_stock':
        return 'Stokta yok';
      default:
        return s;
    }
  }
}

class _FarmerCard extends StatelessWidget {
  final dynamic farmer;
  final ColorScheme cs;
  final VoidCallback onNavigate;
  const _FarmerCard(
      {required this.farmer,
      required this.cs,
      required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final location = [
      if (farmer.city != null && farmer.city!.isNotEmpty) farmer.city!,
      if (farmer.district != null && farmer.district!.isNotEmpty)
        farmer.district!,
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Ürünü Oluşturan Üretici',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (farmer.fullName.isNotEmpty)
              _Row('Adı Soyadı', farmer.fullName, cs),
            if (farmer.displayName.isNotEmpty)
              _Row('Görünen Ad', farmer.displayName, cs),
            if (farmer.phone.isNotEmpty)
              _Row('Telefon', farmer.phone, cs),
            if (location.isNotEmpty)
              _Row('Konum', location, cs),
            _Row(
              'Durum',
              _statusLabel(farmer.status),
              cs,
              valueColor: _statusColor(farmer.status),
            ),
            if (farmer.isFoundingFarmer) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, size: 13, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text('Kurucu Üretici',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('Üretici Profiline Git'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'Aktif';
      case 'suspended':
        return 'Askıya Alındı';
      case 'pending':
        return 'Beklemede';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return AppColors.success;
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;
  const _Row(this.label, this.value, this.cs, {this.valueColor});

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: valueColor))),
        ],
      ),
    );
  }
}
