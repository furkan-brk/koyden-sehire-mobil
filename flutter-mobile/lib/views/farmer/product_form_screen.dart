import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/models/category_model.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';
import 'package:koyden_sehire/services/farmer_product_repository.dart';
import 'package:koyden_sehire/models/farmer_product_model.dart';
import 'package:koyden_sehire/controllers/farmer/my_products_controller.dart';
import 'package:koyden_sehire/controllers/farmer/product_form_controller.dart';

/// Used by both add and edit. Pass `editingId` to load + update.
class ProductFormScreen extends StatefulWidget {
  final String? editingId;
  const ProductFormScreen({super.key, this.editingId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;
  bool _loadingExisting = false;
  String? _loadError;

  ProductFormController get _formCtrl => Get.find<ProductFormController>();

  Future<bool> _confirmDiscard() async {
    final data = _formCtrl.data.value;
    final isDirty = data.title.isNotEmpty || data.imageUrls.isNotEmpty;
    if (!isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Değişiklikler kaybolacak'),
        content: const Text(
            'Çıkmak istediğinize emin misiniz? Girdiğiniz bilgiler kaybolabilir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _handleBack() async {
    if (await _confirmDiscard()) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/farmer/products');
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _formCtrl.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeForm();
    });
  }

  Future<void> _initializeForm() async {
    if (_initialized) return;
    if (widget.editingId != null) {
      setState(() => _loadingExisting = true);
      try {
        final m = await Get.find<FarmerProductRepository>()
            .getById(widget.editingId!);
        _formCtrl.hydrate(m);
      } catch (e) {
        setState(() => _loadError = e.toString());
      } finally {
        if (mounted) setState(() => _loadingExisting = false);
      }
    } else {
      final profile = Get.isRegistered<FarmerProfileController>()
          ? Get.find<FarmerProfileController>().profile.value
          : null;
      if (profile != null) {
        _formCtrl.patch((d) => d.copyWith(
              city: profile.city,
              district: profile.district,
              village: profile.village,
            ));
      }
    }
    _initialized = true;
  }

  Future<void> _pickImage(ImageSource source) async {
    final data = _formCtrl.data.value;
    if (data.imageUrls.length >= AppConstants.maxProductImages) {
      context.snack(
        'En fazla ${AppConstants.maxProductImages} fotoğraf ekleyebilirsiniz',
        isError: true,
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    final List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      context.snack('Fotoğraf okunamadı. Lütfen tekrar deneyin.', isError: true);
      return;
    }

    final ext = picked.name.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png'
        : ext == 'webp' ? 'image/webp'
        : 'image/jpeg';
    final filename = '${DateTime.now().millisecondsSinceEpoch}_product.$ext';

    final ok = await _formCtrl.uploadImage(
      bytes,
      filename: filename,
      contentType: contentType,
    );
    if (!mounted) return;
    if (!ok) {
      final err = _formCtrl.errorMessage.value;
      context.snack(
        err ?? 'Fotoğraf yüklenemedi. Lütfen tekrar deneyin.',
        isError: true,
      );
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kameradan Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Ürün konumu her zaman çiftçinin profil konumundan gelir; çiftçinin
    // ürün başına farklı il/ilçe seçmesine izin verilmez.
    final profile = Get.isRegistered<FarmerProfileController>()
        ? Get.find<FarmerProfileController>().profile.value
        : null;
    if (profile != null) {
      _formCtrl.patch((d) => d.copyWith(
            city: profile.city,
            district: profile.district,
            village: profile.village,
          ));
    }
    final data = _formCtrl.data.value;
    if (data.categoryId == null) {
      context.snack('Kategori seçin', isError: true);
      return;
    }
    if (data.imageUrls.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Fotoğrafsız devam et?'),
          content: const Text(
            'Fotoğraf eklemeniz ürününüzün daha iyi görünmesini sağlar. '
            'Yine de devam etmek ister misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    final ok = await _formCtrl.submit(editingId: widget.editingId);
    if (!mounted) return;
    if (ok) {
      context.toast(widget.editingId == null
          ? 'Ürününüz incelemeye alındı.'
          : 'Ürün güncellendi.');
      Get.find<MyProductsController>().refresh();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/farmer/products');
      }
    } else {
      final err = _formCtrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ürün Düzenle'),
          leading: BackButton(onPressed: _handleBack),
        ),
        body: const AppLoading(),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ürün Düzenle'),
          leading: BackButton(onPressed: _handleBack),
        ),
        body: AppErrorWidget(
          message: _loadError!,
          onRetry: () {
            setState(() {
              _loadError = null;
              _initialized = false;
            });
            _initializeForm();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingId == null ? 'Yeni Ürün' : 'Ürünü Düzenle'),
        leading: BackButton(onPressed: _handleBack),
      ),
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.products),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Obx(() {
              final state = _formCtrl;
              final data = state.data.value;
              final catCtrl = Get.find<CategoryController>();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormSectionCard(
                    child: _ImagePickerSection(
                      imageUrls: data.imageUrls,
                      isUploading: state.isUploadingImage.value,
                      onAdd: _showImageSourceSheet,
                      onRemove: (i) => state.removeImage(i),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          icon: Icons.category_outlined,
                          title: 'Kategori',
                        ),
                        const SizedBox(height: 12),
                        if (catCtrl.isLoading.value)
                          const Center(child: CircularProgressIndicator())
                        else if (catCtrl.error.value != null)
                          const Text(
                            'Kategoriler yüklenemedi',
                            style: TextStyle(
                                color: AppColors.onSurfaceVariant),
                          )
                        else
                          _CategorySelector(
                            categories: catCtrl.categories,
                            selected: data,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          icon: Icons.description_outlined,
                          title: 'Ürün Bilgileri',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Ürün Adı',
                          hint: 'Günlük Köy Çileği',
                          initialValue: data.title,
                          maxLength: 255,
                          onChanged: (v) =>
                              state.patch((d) => d.copyWith(title: v)),
                          validator: (v) =>
                              Validators.required(v, field: 'Ürün adı'),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Açıklama',
                          hint:
                              'Ürününüzü tanıtın: hasat zamanı, üretim şekli, lezzet özellikleri...',
                          initialValue: data.description,
                          maxLines: 5,
                          onChanged: (v) =>
                              state.patch((d) => d.copyWith(description: v)),
                          validator: (v) =>
                              Validators.required(v, field: 'Açıklama'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          icon: Icons.sell_outlined,
                          title: 'Fiyat & Stok',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: AppTextField(
                                label: 'Fiyat',
                                prefix: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    '₺',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                initialValue: data.price,
                                onChanged: (v) =>
                                    state.patch((d) => d.copyWith(price: v)),
                                validator: Validators.positiveNumber,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: data.unit,
                                decoration: const InputDecoration(
                                  labelText: 'Birim',
                                  prefixIcon: Icon(
                                    Icons.straighten_outlined,
                                    size: 18,
                                  ),
                                ),
                                items: productUnits
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  state.patch((d) => d.copyWith(unit: v));
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Stok Durumu',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StockToggle(
                          current: data.stockStatus,
                          onChanged: (v) => state
                              .patch((d) => d.copyWith(stockStatus: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _LocationInfoCard(),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: widget.editingId == null
                        ? 'Ürünü Yayına Gönder'
                        : 'Değişiklikleri Kaydet',
                    isLoading: state.isSubmitting.value,
                    onPressed: state.isSubmitting.value ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ImagePickerSection extends StatelessWidget {
  final List<String> imageUrls;
  final bool isUploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImagePickerSection({
    required this.imageUrls,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final canAddMore = imageUrls.length < AppConstants.maxProductImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.photo_camera_outlined,
          title: 'Ürün Fotoğrafları',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '${imageUrls.length} / ${AppConstants.maxProductImages}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (imageUrls.isEmpty)
          _BigImageDropZone(
            isUploading: isUploading,
            onTap: isUploading ? null : onAdd,
          )
        else ...[
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length + (canAddMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                if (i == imageUrls.length) {
                  return _AddImageTile(
                    onTap: isUploading ? null : onAdd,
                    isUploading: isUploading,
                  );
                }
                return _ThumbWithRemove(
                  url: imageUrls[i],
                  isCover: i == 0,
                  onRemove: () => onRemove(i),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'İlk fotoğraf, ürünün kapak görseli olur.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _BigImageDropZone extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;
  const _BigImageDropZone({required this.onTap, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: DottedBorder(
        color: AppColors.primaryContainer,
        radius: AppRadius.lg,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          alignment: Alignment.center,
          child: isUploading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Yükleniyor…',
                      style: TextStyle(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 32,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fotoğraf Ekle',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryContainer,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Galeriden seçin veya kameradan çekin\n(en fazla 5 fotoğraf)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ThumbWithRemove extends StatelessWidget {
  final String url;
  final bool isCover;
  final VoidCallback onRemove;
  const _ThumbWithRemove({
    required this.url,
    required this.isCover,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            width: 110,
            height: 110,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.surfaceContainerLow,
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surfaceContainerLow,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        if (isCover)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                'Kapak',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;
  const _AddImageTile({required this.onTap, required this.isUploading});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: DottedBorder(
        color: AppColors.primaryContainer,
        radius: AppRadius.md,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          alignment: Alignment.center,
          child: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 28,
                      color: AppColors.primaryContainer,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ekle',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Lightweight dashed-border wrapper — avoids adding a new package.
class DottedBorder extends StatelessWidget {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;
  final Widget child;

  const DottedBorder({
    super.key,
    required this.color,
    required this.child,
    this.strokeWidth = 1.5,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace ||
      old.radius != radius;
}

class _FormSectionCard extends StatelessWidget {
  final Widget child;
  const _FormSectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CategorySelector extends StatefulWidget {
  final List<CategoryModel> categories;
  final ProductFormData selected;
  const _CategorySelector(
      {required this.categories, required this.selected});
  @override
  State<_CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<_CategorySelector> {
  String? _mainId;

  @override
  void initState() {
    super.initState();
    final flat = Get.find<CategoryController>().flat;
    final selectedId = widget.selected.categoryId;
    if (selectedId != null) {
      final cat = findCategoryById(flat, selectedId);
      _mainId = cat?.parentId ?? cat?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roots = widget.categories.where((c) => c.isRoot).toList();
    final mainCategory = _mainId == null
        ? null
        : roots.firstWhereOrNull((c) => c.id == _mainId);
    final subs = mainCategory?.children ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _mainId,
          decoration: const InputDecoration(labelText: 'Ana Kategori'),
          items: roots
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: (v) {
            setState(() => _mainId = v);
            Get.find<ProductFormController>().patch(
              (d) => d.copyWith(categoryId: null),
            );
          },
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: subs.any((s) => s.id == widget.selected.categoryId)
                ? widget.selected.categoryId
                : null,
            decoration: const InputDecoration(labelText: 'Alt Kategori'),
            items: subs
                .map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) {
              Get.find<ProductFormController>().patch(
                (d) => d.copyWith(categoryId: v),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _LocationInfoCard extends StatelessWidget {
  const _LocationInfoCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final profile = Get.isRegistered<FarmerProfileController>()
          ? Get.find<FarmerProfileController>().profile.value
          : null;
      final parts = <String>[
        if ((profile?.city ?? '').isNotEmpty) profile!.city,
        if ((profile?.district ?? '').isNotEmpty) profile!.district,
        if ((profile?.village ?? '').isNotEmpty) profile!.village,
      ];
      final locationLine = parts.isEmpty ? '—' : parts.join(' / ');

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md - 2),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined,
                size: 22, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İlan Konumu',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ürün konumu, çiftlik profilinizdeki konumdan otomatik alınır.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    locationLine,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _StockToggle extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _StockToggle({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'available',
          label: Text('Mevcut'),
          icon: Icon(Icons.check_circle_outline),
        ),
        ButtonSegment(
          value: 'out_of_stock',
          label: Text('Tükendi'),
          icon: Icon(Icons.remove_circle_outline),
        ),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
