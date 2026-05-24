import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
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
            const SizedBox(height: 24),
            // Bildirimlerim kartı
            _FarmerNotificationsCard(),
            const SizedBox(height: 12),
            // Hesap İşlemleri kartı
            _AccountActionsCard(),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Bildirimlerim kartı
// ---------------------------------------------------------------------------

class _FarmerNotificationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.notifications_outlined,
                    size: 16, color: AppColors.onSurfaceVariant),
                SizedBox(width: 6),
                Text(
                  'Bildirimlerim',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Ürün onayları, başvuru durumu ve platform duyurularını buradan takip edebilirsin.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                _PreviewItem(
                    icon: Icons.check_circle_outline,
                    text: 'Ürün onay/red bildirimleri burada görünecek',
                    color: AppColors.success),
                SizedBox(height: 6),
                _PreviewItem(
                    icon: Icons.campaign_outlined,
                    text: 'Platform duyuruları burada görünecek',
                    color: AppColors.primaryContainer),
                SizedBox(height: 6),
                _PreviewItem(
                    icon: Icons.account_circle_outlined,
                    text: 'Başvuru ve hesap bildirimleri burada görünecek',
                    color: AppColors.primaryContainer),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          InkWell(
            onTap: () => context.push('/farmer/notifications'),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.md)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.primaryContainer),
                  SizedBox(width: 8),
                  Text(
                    'Bildirimleri Gör',
                    style: TextStyle(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _PreviewItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hesap İşlemleri kartı
// ---------------------------------------------------------------------------

class _AccountActionsCard extends StatelessWidget {
  Future<void> _confirmLogout(BuildContext context) async {
    final auth = Get.find<AuthService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await auth.logout();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Hesap İşlemleri',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          InkWell(
            onTap: () => _confirmLogout(context),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.md)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.logout, size: 22, color: AppColors.error),
                  SizedBox(width: 12),
                  Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
