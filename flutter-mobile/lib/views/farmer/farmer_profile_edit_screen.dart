import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/models/farmer_profile_edit_model.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
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

  Future<void> _pickProfileImage(ImageSource source) async {
    if (!kIsWeb && source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (mounted) {
          context.snack(
            'Kamerayı açmak için lütfen ayarlardan kamera iznini verin.',
            isError: true,
          );
        }
        return;
      }
      if (!status.isGranted) return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      context.snack('Fotoğraf okunamadı. Lütfen tekrar deneyin.',
          isError: true);
      return;
    }

    final ext = picked.name.split('.').last.toLowerCase();
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    final filename = '${DateTime.now().millisecondsSinceEpoch}_profile.$ext';

    final ok = await _ctrl.uploadProfileImage(bytes,
        filename: filename, contentType: contentType);
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
      if (context.canPop()) context.pop();
    } else {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
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
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kameradan Çek'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Düzenle'),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _ProfileFormCard(
              profile: p,
              ctrl: ctrl,
              formKey: _formKey,
              onPickImage: _showImageSourceSheet,
              onSave: _save,
            ),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profil form kartı
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileFormCard extends StatelessWidget {
  final FarmerProfileEdit profile;
  final FarmerProfileController ctrl;
  final GlobalKey<FormState> formKey;
  final VoidCallback onPickImage;
  final Future<void> Function() onSave;

  const _ProfileFormCard({
    required this.profile,
    required this.ctrl,
    required this.formKey,
    required this.onPickImage,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.surfaceContainerLow,
                  backgroundImage: profile.profileImageUrl == null
                      ? null
                      : CachedNetworkImageProvider(
                          profile.profileImageUrl!),
                  child: profile.profileImageUrl == null
                      ? const Icon(Icons.person, size: 44)
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
                          : onPickImage,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.camera_alt_outlined,
                            color: Colors.white, size: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (ctrl.isUploadingImage.value) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          // Form alanları
          Form(
            key: formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'Üretici Adı',
                  initialValue: profile.displayName,
                  onChanged: (v) =>
                      ctrl.edit((e) => e.copyWith(displayName: v)),
                  validator: (v) =>
                      Validators.required(v, field: 'Üretici adı'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: profile.producerType,
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
                  initialValue: profile.city,
                  onChanged: (v) =>
                      ctrl.edit((e) => e.copyWith(city: v)),
                  validator: (v) =>
                      Validators.required(v, field: 'İl'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'İlçe',
                  initialValue: profile.district,
                  onChanged: (v) =>
                      ctrl.edit((e) => e.copyWith(district: v)),
                  validator: (v) =>
                      Validators.required(v, field: 'İlçe'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Köy / Mahalle',
                  initialValue: profile.village,
                  onChanged: (v) =>
                      ctrl.edit((e) => e.copyWith(village: v)),
                  validator: (v) =>
                      Validators.required(v, field: 'Köy/Mahalle'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Açık Adres',
                  initialValue: profile.address,
                  maxLines: 2,
                  onChanged: (v) =>
                      ctrl.edit((e) => e.copyWith(address: v)),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Biyografi',
                  initialValue: profile.bio,
                  maxLines: 4,
                  onChanged: (v) =>
                      ctrl.edit((e) => e.copyWith(bio: v)),
                  validator: (v) =>
                      Validators.required(v, field: 'Biyografi'),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Değişiklikleri Kaydet',
                  isLoading: ctrl.isSaving.value,
                  onPressed: ctrl.isSaving.value ? null : () => onSave(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
