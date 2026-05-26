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
                  _ImagePickerSection(
                    imageUrls: data.imageUrls,
                    isUploading: state.isUploadingImage.value,
                    onAdd: _showImageSourceSheet,
                    onRemove: (i) => state.removeImage(i),
                  ),
                  const SizedBox(height: 16),
                  if (catCtrl.isLoading.value)
                    const Center(child: CircularProgressIndicator())
                  else if (catCtrl.error.value != null)
                    const Text(
                      'Kategoriler yüklenemedi',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    )
                  else
                    _CategorySelector(
                      categories: catCtrl.categories,
                      selected: data,
                    ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Ürün Adı',
                    hint: 'Günlük Köy Çileği',
                    initialValue: data.title,
                    maxLength: 255,
                    onChanged: (v) => state.patch((d) => d.copyWith(title: v)),
                    validator: (v) => Validators.required(v, field: 'Ürün adı'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Açıklama',
                    hint: 'Ürününüzü tanıtın...',
                    initialValue: data.description,
                    maxLines: 5,
                    onChanged: (v) =>
                        state.patch((d) => d.copyWith(description: v)),
                    validator: (v) =>
                        Validators.required(v, field: 'Açıklama'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Fiyat',
                          prefix: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('₺',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          initialValue: data.price,
                          onChanged: (v) =>
                              state.patch((d) => d.copyWith(price: v)),
                          validator: Validators.positiveNumber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: data.unit,
                          decoration:
                              const InputDecoration(labelText: 'Birim'),
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
                  const SizedBox(height: 12),
                  _StockToggle(
                    current: data.stockStatus,
                    onChanged: (v) =>
                        state.patch((d) => d.copyWith(stockStatus: v)),
                  ),
                  const SizedBox(height: 16),
                  const _LocationInfoCard(),
                  const SizedBox(height: 24),
                  AppButton(
                    label: widget.editingId == null
                        ? 'Ürünü Yayına Gönder'
                        : 'Değişiklikleri Kaydet',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ürün Fotoğrafları (${imageUrls.length}/${AppConstants.maxProductImages})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: CachedNetworkImage(
                        imageUrl: imageUrls[i],
                        fit: BoxFit.cover,
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
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        alignment: Alignment.center,
        child: isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined,
                color: AppColors.onSurfaceVariant),
      ),
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
