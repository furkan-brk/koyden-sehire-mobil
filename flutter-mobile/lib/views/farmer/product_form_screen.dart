import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/utils/confirm_dialog.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/models/category_model.dart';
import 'package:koyden_sehire/models/product_form_config.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';
import 'package:koyden_sehire/services/farmer_product_repository.dart';
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
    return showConfirmDialog(
      context,
      title: 'Formu Kapat',
      message: 'Kaydedilmemiş değişiklikler kaybolacak.',
      confirmLabel: 'Çık',
      isDestructive: true,
    );
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
        final m = await Get.find<FarmerProductRepository>().getById(widget.editingId!);
        _formCtrl.hydrate(m);
      } catch (e) {
        setState(() => _loadError = e.toString());
      } finally {
        if (mounted) setState(() => _loadingExisting = false);
      }
    } else {
      final profile =
          Get.isRegistered<FarmerProfileController>() ? Get.find<FarmerProfileController>().profile.value : null;
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
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile =
        Get.isRegistered<FarmerProfileController>() ? Get.find<FarmerProfileController>().profile.value : null;
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
      context.toast(widget.editingId == null ? 'Ürününüz incelemeye alındı.' : 'Ürün güncellendi.');
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
      // Pushed route — BottomNav gösterilmez; tab değişimi form verisini kaybettirirdi.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Obx(() {
              final state = _formCtrl;
              final data = state.data.value;
              final catCtrl = Get.find<CategoryController>();

              // ── Tamamlanma durumu ──────────────────────────────────────
              final isPhotosComplete = data.imageUrls.isNotEmpty;
              final isCategoryComplete = data.categoryId != null;
              final isBasicInfoComplete = data.title.trim().isNotEmpty && data.description.trim().isNotEmpty;
              final isPricingComplete =
                  data.price.isNotEmpty && (double.tryParse(data.price.replaceAll(',', '.')) ?? 0) > 0;
              // Stok durumu her zaman bir değere sahip (default: 'available')
              const isStockComplete = true;

              final completedCount = [
                isCategoryComplete,
                isBasicInfoComplete,
                isPricingComplete,
                isStockComplete,
              ].where((b) => b).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── İlerleme Çubuğu ─────────────────────────────────
                  _FormProgressChip(
                    completed: completedCount,
                    total: ProductFormConfig.requiredSectionCount,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Fotoğraflar ──────────────────────────────────────
                  _SectionCard(
                    title:
                        '${ProductFormConfig.photos.title} (${data.imageUrls.length}/${AppConstants.maxProductImages})',
                    icon: ProductFormConfig.photos.icon,
                    subtitle: ProductFormConfig.photos.subtitle,
                    isComplete: isPhotosComplete,
                    child: _ImagePickerSection(
                      imageUrls: data.imageUrls,
                      isUploading: state.isUploadingImage.value,
                      onAdd: _showImageSourceSheet,
                      onRemove: (i) => state.removeImage(i),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),

                  // ── Kategori ─────────────────────────────────────────
                  _SectionCard(
                    title: ProductFormConfig.category.title,
                    icon: ProductFormConfig.category.icon,
                    subtitle: ProductFormConfig.category.subtitle,
                    isComplete: isCategoryComplete,
                    child: catCtrl.isLoading.value
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : catCtrl.error.value != null
                            ? const Text(
                                'Kategoriler yüklenemedi',
                                style: TextStyle(color: AppColors.onSurfaceVariant),
                              )
                            : _CategorySelector(
                                categories: catCtrl.categories,
                                selected: data,
                              ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),

                  // ── Ürün Bilgileri ───────────────────────────────────
                  _SectionCard(
                    title: ProductFormConfig.basicInfo.title,
                    icon: ProductFormConfig.basicInfo.icon,
                    subtitle: ProductFormConfig.basicInfo.subtitle,
                    isComplete: isBasicInfoComplete,
                    child: Column(
                      children: [
                        AppTextField(
                          label: ProductFormConfig.titleField.label,
                          hint: ProductFormConfig.titleField.hint,
                          helperText: ProductFormConfig.titleField.helperText,
                          initialValue: data.title,
                          maxLength: ProductFormConfig.titleField.maxLength,
                          onChanged: (v) => state.patch((d) => d.copyWith(title: v)),
                          validator: (v) => Validators.required(v, field: 'Ürün adı'),
                        ),
                        const SizedBox(height: AppSpacing.sm + 4),
                        AppTextField(
                          label: ProductFormConfig.descriptionField.label,
                          hint: ProductFormConfig.descriptionField.hint,
                          initialValue: data.description,
                          maxLines: 5,
                          onChanged: (v) => state.patch((d) => d.copyWith(description: v)),
                          validator: (v) => Validators.required(v, field: 'Açıklama'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),

                  // ── Fiyat & Birim ────────────────────────────────────
                  _SectionCard(
                    title: ProductFormConfig.pricing.title,
                    icon: ProductFormConfig.pricing.icon,
                    subtitle: ProductFormConfig.pricing.subtitle,
                    isComplete: isPricingComplete,
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: ProductFormConfig.priceField.label,
                            hint: ProductFormConfig.priceField.hint,
                            helperText: ProductFormConfig.priceField.helperText,
                            prefix: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('₺', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            initialValue: data.price,
                            onChanged: (v) => state.patch((d) => d.copyWith(price: v)),
                            validator: Validators.positiveNumber,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm + 4),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: data.unit,
                            decoration: const InputDecoration(labelText: 'Birim'),
                            items: productUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              state.patch((d) => d.copyWith(unit: v));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),

                  // ── Stok Durumu ──────────────────────────────────────
                  _SectionCard(
                    title: ProductFormConfig.stock.title,
                    icon: ProductFormConfig.stock.icon,
                    subtitle: ProductFormConfig.stock.subtitle,
                    isComplete: isStockComplete,
                    child: _StockToggle(
                      current: data.stockStatus,
                      onChanged: (v) => state.patch((d) => d.copyWith(stockStatus: v)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),

                  // ── Konum ────────────────────────────────────────────
                  const _LocationInfoCard(),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: widget.editingId == null ? 'Ürünü Yayına Gönder' : 'Değişiklikleri Kaydet',
                    isLoading: state.isSubmitting.value,
                    onPressed: state.isSubmitting.value ? null : _submit,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Form Progress Chip ───────────────────────────────────────────────────────

class _FormProgressChip extends StatelessWidget {
  final int completed;
  final int total;

  const _FormProgressChip({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDone = completed >= total;
    final progress = total > 0 ? completed / total : 0.0;
    final progressColor = isDone ? Colors.green.shade600 : cs.primary;
    final label = isDone ? 'Göndermeye hazır ✓' : '$completed / $total zorunlu bölüm tamamlandı';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: progressColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final bool isComplete;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.isComplete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isComplete) Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
            ],
          ),
          // Alt açıklama
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          child,
        ],
      ),
    );
  }
}

// ─── Image Picker ──────────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          if (i == imageUrls.length) {
            return _AddImageTile(
              onTap: isUploading ? null : onAdd,
              isUploading: isUploading,
            );
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: cs.surfaceContainer,
                      highlightColor: cs.surfaceContainerLow,
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerLow,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;
  const _AddImageTile({required this.onTap, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outlineVariant),
        ),
        alignment: Alignment.center,
        child: isUploading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: cs.onSurfaceVariant, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    'Fotoğraf Ekle',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Category Selector ────────────────────────────────────────────────────────

class _CategorySelector extends StatefulWidget {
  final List<CategoryModel> categories;
  final ProductFormData selected;
  const _CategorySelector({required this.categories, required this.selected});

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
    final mainCategory = _mainId == null ? null : roots.firstWhereOrNull((c) => c.id == _mainId);
    final subs = mainCategory?.children ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _mainId,
          decoration: const InputDecoration(labelText: 'Ana Kategori'),
          items: roots.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          onChanged: (v) {
            setState(() => _mainId = v);
            Get.find<ProductFormController>().patch(
              (d) => d.copyWith(categoryId: null),
            );
          },
        ),
        if (subs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          DropdownButtonFormField<String>(
            value: subs.any((s) => s.id == widget.selected.categoryId) ? widget.selected.categoryId : null,
            decoration: const InputDecoration(labelText: 'Alt Kategori'),
            items: subs.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
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

// ─── Location Info Card ───────────────────────────────────────────────────────

class _LocationInfoCard extends StatelessWidget {
  const _LocationInfoCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final profile =
          Get.isRegistered<FarmerProfileController>() ? Get.find<FarmerProfileController>().profile.value : null;
      final parts = <String>[
        if ((profile?.city ?? '').isNotEmpty) profile!.city,
        if ((profile?.district ?? '').isNotEmpty) profile!.district,
        if ((profile?.village ?? '').isNotEmpty) profile!.village,
      ];
      final locationLine = parts.isEmpty ? '—' : parts.join(' / ');

      return Container(
        padding: const EdgeInsets.all(AppSpacing.md - 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        ProductFormConfig.location.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ProductFormConfig.location.subtitle,
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

// ─── Stock Toggle ─────────────────────────────────────────────────────────────

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
