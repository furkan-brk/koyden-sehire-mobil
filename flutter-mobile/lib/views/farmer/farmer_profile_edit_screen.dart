import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/utils/confirm_dialog.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/models/farmer_profile_edit_model.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';
import 'package:koyden_sehire/controllers/farmer/dashboard_controller.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_notifications_controller.dart';

class FarmerProfileEditScreen extends StatefulWidget {
  const FarmerProfileEditScreen({super.key});

  @override
  State<FarmerProfileEditScreen> createState() => _FarmerProfileEditScreenState();
}

class _FarmerProfileEditScreenState extends State<FarmerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  FarmerProfileController get _ctrl => Get.find<FarmerProfileController>();
  DashboardController get _dashCtrl => Get.find<DashboardController>();
  FarmerNotificationsController get _notifsCtrl => Get.find<FarmerNotificationsController>();

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
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    final filename = '${DateTime.now().millisecondsSinceEpoch}_profile.$ext';

    final ok = await _ctrl.uploadProfileImage(bytes, filename: filename, contentType: contentType);
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

  Future<void> _confirmLogout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Çıkış Yap',
      message: 'Hesabınızdan çıkmak istediğinize emin misiniz?',
      confirmLabel: 'Çıkış Yap',
      isDestructive: true,
    );
    if (!ok) return;
    await Get.find<AuthService>().logout();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profilim'),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── İstatistikler ───────────────────────────────────────────
            _StatsRow(dashCtrl: _dashCtrl),
            const SizedBox(height: 24),

            // ── Profil Bilgileri ────────────────────────────────────────
            const _SectionHeader(
              icon: Icons.person_outline,
              title: 'Profil Bilgileri',
            ),
            const SizedBox(height: 10),
            _ProfileFormCard(
              profile: p,
              ctrl: ctrl,
              formKey: _formKey,
              onPickImage: _pickProfileImage,
              onSave: _save,
            ),
            const SizedBox(height: 24),

            // ── Bildirimler ─────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.notifications_outlined,
              title: 'Bildirimler',
              trailing: Obx(() {
                final count = _notifsCtrl.unreadCount.value;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            _NotifPreviewCard(
              ctrl: _notifsCtrl,
              onSeeAll: () => context.push('/farmer/notifications'),
            ),
            const SizedBox(height: 24),

            // ── Hesap ───────────────────────────────────────────────────
            const _SectionHeader(
              icon: Icons.manage_accounts_outlined,
              title: 'Hesap',
            ),
            const SizedBox(height: 10),
            _AccountCard(
              profile: p,
              ctrl: ctrl,
              onLogout: _confirmLogout,
            ),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cs.primary,
            letterSpacing: 0.8,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İstatistik satırı
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DashboardController dashCtrl;
  const _StatsRow({required this.dashCtrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = dashCtrl.data.value;
      return Row(
        children: [
          _StatChip(
            label: 'Aktif Ürün',
            value: data?.activeCount.toString() ?? '--',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Bekleyen',
            value: data?.pendingCount.toString() ?? '--',
            icon: Icons.hourglass_bottom,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Davet Hakkı',
            value: data?.inviteRemaining.toString() ?? '--',
            icon: Icons.card_giftcard_outlined,
            color: AppColors.primaryContainer,
          ),
        ],
      );
    });
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profil Bilgileri kartı
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
                  backgroundImage:
                      profile.profileImageUrl == null ? null : CachedNetworkImageProvider(profile.profileImageUrl!),
                  child: profile.profileImageUrl == null ? const Icon(Icons.person, size: 44) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: ctrl.isUploadingImage.value ? null : onPickImage,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
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
                  onChanged: (v) => ctrl.edit((e) => e.copyWith(displayName: v)),
                  validator: (v) => Validators.required(v, field: 'Üretici adı'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: profile.producerType,
                  decoration: const InputDecoration(labelText: 'Üretici Tipi'),
                  items: producerTypeLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => ctrl.edit((e) => e.copyWith(producerType: v)),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'İl',
                  initialValue: profile.city,
                  onChanged: (v) => ctrl.edit((e) => e.copyWith(city: v)),
                  validator: (v) => Validators.required(v, field: 'İl'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'İlçe',
                  initialValue: profile.district,
                  onChanged: (v) => ctrl.edit((e) => e.copyWith(district: v)),
                  validator: (v) => Validators.required(v, field: 'İlçe'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Köy / Mahalle',
                  initialValue: profile.village,
                  onChanged: (v) => ctrl.edit((e) => e.copyWith(village: v)),
                  validator: (v) => Validators.required(v, field: 'Köy/Mahalle'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Biyografi',
                  initialValue: profile.bio,
                  maxLines: 4,
                  onChanged: (v) => ctrl.edit((e) => e.copyWith(bio: v)),
                  validator: (v) => Validators.required(v, field: 'Biyografi'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Bildirim önizleme kartı
// ─────────────────────────────────────────────────────────────────────────────

class _NotifPreviewCard extends StatelessWidget {
  final FarmerNotificationsController ctrl;
  final VoidCallback onSeeAll;

  const _NotifPreviewCard({required this.ctrl, required this.onSeeAll});

  (IconData, Color) _iconFor(String type) => switch (type) {
        'product_approved' => (Icons.check_circle_outline, AppColors.success),
        'product_rejected' => (Icons.cancel_outlined, AppColors.error),
        'product_needs_edit' => (Icons.edit_outlined, AppColors.warning),
        'account_approved' => (Icons.account_circle_outlined, AppColors.success),
        _ => (Icons.campaign_outlined, AppColors.primaryContainer),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Obx(() {
        final items = ctrl.items.take(3).toList();
        final isEmpty = ctrl.items.isEmpty;
        final isLoading = ctrl.isLoading.value && isEmpty;

        if (isLoading) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          children: [
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Row(
                  children: [
                    Icon(Icons.notifications_none, color: AppColors.onSurfaceVariant, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Henüz bildiriminiz yok',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ...items.map((n) {
                final (icon, color) = _iconFor(n.type);
                return Column(
                  children: [
                    InkWell(
                      onTap: () => context.push('/farmer/notifications'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    AppFormatters.date(n.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (n != items.last) const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }),
            const Divider(height: 1, thickness: 1),
            InkWell(
              onTap: onSeeAll,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.primaryContainer),
                    SizedBox(width: 8),
                    Text(
                      'Tüm Bildirimleri Gör',
                      style: TextStyle(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hesap kartı
// ─────────────────────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final FarmerProfileEdit profile;
  final FarmerProfileController ctrl;
  final Future<void> Function() onLogout;

  const _AccountCard({
    required this.profile,
    required this.ctrl,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          // Telefon görünürlüğü
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, color: AppColors.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İletişim Telefonu',
                        style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
                      ),
                      Text(
                        profile.publicPhone.isEmpty ? '-' : PhoneFormatter.pretty(profile.publicPhone),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            value: profile.showPhone,
            onChanged: (v) => ctrl.edit((e) => e.copyWith(showPhone: v)),
            title: const Text(
              'Telefonum ürün sayfalarında görünsün',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Çıkış
          InkWell(
            onTap: onLogout,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: AppColors.error),
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
