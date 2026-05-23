import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';

class FarmerProfileEditScreen extends StatefulWidget {
  const FarmerProfileEditScreen({super.key});

  @override
  State<FarmerProfileEditScreen> createState() =>
      _FarmerProfileEditScreenState();
}

class _FarmerProfileEditScreenState extends State<FarmerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  FarmerProfileController get _ctrl => Get.find<FarmerProfileController>();

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
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
    final filename = '${DateTime.now().millisecondsSinceEpoch}_profile.$ext';

    final ok = await _ctrl.uploadProfileImage(
      bytes,
      filename: filename,
      contentType: contentType,
    );
    if (!mounted) return;
    if (ok) {
      context.toast('Profil fotoğrafı güncellendi');
    } else {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await _ctrl.save();
    if (!mounted) return;
    if (ok) {
      context.toast('Profil güncellendi');
    } else {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profil'),
      ),
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.profile),
      body: Obx(() {
        final ctrl = _ctrl;
        if (ctrl.isLoading.value && ctrl.profile.value == null) {
          return const AppLoading();
        }
        if (ctrl.profile.value == null) {
          return AppErrorWidget(
            message: ctrl.errorMessage.value ?? 'Profil yüklenemedi',
            onRetry: ctrl.load,
          );
        }
        final p = ctrl.profile.value!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.surfaceContainerLow,
                    backgroundImage: p.profileImageUrl == null
                        ? null
                        : CachedNetworkImageProvider(p.profileImageUrl!),
                    child: p.profileImageUrl == null
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: ctrl.isUploadingImage.value
                            ? null
                            : _pickProfileImage,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (ctrl.isUploadingImage.value) ...[
              const SizedBox(height: 8),
              const Center(child: LinearProgressIndicator()),
            ],
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Üretici Adı',
                    initialValue: p.displayName,
                    onChanged: (v) => ctrl.edit((e) => e.copyWith(displayName: v)),
                    validator: (v) =>
                        Validators.required(v, field: 'Üretici adı'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: p.producerType,
                    decoration:
                        const InputDecoration(labelText: 'Üretici Tipi'),
                    items: producerTypeLabels.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) =>
                        ctrl.edit((e) => e.copyWith(producerType: v)),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'İl',
                    initialValue: p.city,
                    onChanged: (v) => ctrl.edit((e) => e.copyWith(city: v)),
                    validator: (v) => Validators.required(v, field: 'İl'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'İlçe',
                    initialValue: p.district,
                    onChanged: (v) => ctrl.edit((e) => e.copyWith(district: v)),
                    validator: (v) => Validators.required(v, field: 'İlçe'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Köy / Mahalle',
                    initialValue: p.village,
                    onChanged: (v) => ctrl.edit((e) => e.copyWith(village: v)),
                    validator: (v) =>
                        Validators.required(v, field: 'Köy/Mahalle'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Biyografi',
                    initialValue: p.bio,
                    maxLines: 4,
                    onChanged: (v) => ctrl.edit((e) => e.copyWith(bio: v)),
                    validator: (v) =>
                        Validators.required(v, field: 'Biyografi'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'İletişim Telefonu',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                p.publicPhone.isEmpty
                                    ? '-'
                                    : PhoneFormatter.pretty(p.publicPhone),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: p.showPhone,
                    onChanged: (v) =>
                        ctrl.edit((e) => e.copyWith(showPhone: v)),
                    title: const Text(
                      'Telefonum ürün sayfalarında görünsün',
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Değişiklikleri Kaydet',
                    isLoading: ctrl.isSaving.value,
                    onPressed: ctrl.isSaving.value ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
