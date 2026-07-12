import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/customer/customer_notifications_controller.dart';
import 'package:koyden_sehire/controllers/customer/customer_profile_controller.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/recent_views_service.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/models/customer_profile_model.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/utils/app_permissions.dart';
import 'package:koyden_sehire/shared/utils/confirm_dialog.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/legal_links_card.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  CustomerProfileController get _ctrl =>
      Get.find<CustomerProfileController>();

  Future<void> _pickProfileImage(ImageSource source) async {
    if (!kIsWeb && source == ImageSource.camera) {
      final granted = await ensurePermissions(
        context,
        [Permission.camera],
        deniedMessage:
            'Kamerayı açmak için lütfen ayarlardan kamera iznini verin.',
      );
      if (!granted) return;
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
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_profile.$ext';

    final ok = await _ctrl.uploadProfileImage(bytes,
        filename: filename, contentType: contentType);
    if (!mounted) return;
    if (ok) {
      context.toast('Profil resmi güncellendi');
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
    final recentSvc = Get.find<RecentViewsService>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profilim'),
      ),
      bottomNavigationBar:
          const CustomerBottomNav(current: CustomerTab.profile),
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.profile.value == null) {
          return const AppLoading();
        }
        if (_ctrl.errorMessage.value != null &&
            _ctrl.profile.value == null) {
          return AppErrorWidget(
            message: _ctrl.errorMessage.value!,
            onRetry: _ctrl.load,
          );
        }
        final profile = _ctrl.profile.value;
        if (profile == null) return const AppLoading();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Header ────────────────────────────────────────────────
            _ProfileHeaderCard(
              profile: profile,
              ctrl: _ctrl,
              onPickImage: _showImageSourceSheet,
            ),
            const SizedBox(height: 24),

            // ── Hesap Bilgileri tıklanabilir kart ─────────────────────
            const _SectionHeader(
              icon: Icons.person_outline,
              title: 'Hesap Bilgileri',
            ),
            const SizedBox(height: 10),
            _AccountInfoCard(
              onTap: () => context.push('/customer/profile/edit'),
            ),
            const SizedBox(height: 24),

            // ── Son Görüntülenenler ───────────────────────────────────
            Obx(() {
              if (recentSvc.items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: Icons.history,
                    title: 'Son Görüntülenenler',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentSvc.items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final entry = recentSvc.items[i];
                        return _RecentChip(
                          entry: entry,
                          onTap: () {
                            if (entry.type == RecentViewType.product) {
                              ctx.push('/products/${entry.id}');
                            } else {
                              ctx.push('/farmers/${entry.id}');
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),

            // ── Bildirimler ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _SectionHeader(
                  icon: Icons.notifications_outlined,
                  title: 'Bildirimler',
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/customer/notifications'),
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CustomerNotifPreviewCard(
              onSeeAll: () =>
                  context.push('/customer/notifications'),
            ),
            const SizedBox(height: 24),

            // ── Yasal ─────────────────────────────────────────────────
            const _SectionHeader(
              icon: Icons.gavel_outlined,
              title: 'Yasal',
            ),
            const SizedBox(height: 10),
            const LegalLinksCard(),
            const SizedBox(height: 24),

            // ── Hesap ─────────────────────────────────────────────────
            const _SectionHeader(
              icon: Icons.manage_accounts_outlined,
              title: 'Hesap',
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: InkWell(
                onTap: _confirmLogout,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.logout,
                          size: 20, color: AppColors.error),
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
            ),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paylaşılan bileşenler
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.primary),
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
      ],
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AccountInfoCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.person_outline,
                    size: 18, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hesap Bilgileri',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ad soyad, e-posta ve telefon bilgilerinizi görüntüleyin.',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final CustomerProfileModel profile;
  final CustomerProfileController ctrl;
  final VoidCallback onPickImage;

  const _ProfileHeaderCard({
    required this.profile,
    required this.ctrl,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: cs.primaryContainer.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.secondaryContainer,
                backgroundImage: profile.profileImageUrl == null
                    ? null
                    : CachedNetworkImageProvider(
                        profile.profileImageUrl!),
                child: profile.profileImageUrl == null
                    ? Icon(Icons.person,
                        size: 32, color: cs.primaryContainer)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Obx(() {
                  final uploading = ctrl.isUploadingImage.value;
                  return Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: uploading ? null : onPickImage,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                ),
                              )
                            : const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Müşteri Hesabı',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: cs.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  final RecentViewEntry entry;
  final VoidCallback onTap;
  const _RecentChip({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 38,
                height: 38,
                child: entry.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: entry.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _RecentPlaceholder(type: entry.type),
                      )
                    : _RecentPlaceholder(type: entry.type),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              entry.title,
              style: const TextStyle(fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlaceholder extends StatelessWidget {
  final RecentViewType type;
  const _RecentPlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLow,
      child: Icon(
        type == RecentViewType.product
            ? Icons.shopping_bag_outlined
            : Icons.storefront_outlined,
        size: 18,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer notification preview card
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerNotifPreviewCard extends StatelessWidget {
  final VoidCallback onSeeAll;

  const _CustomerNotifPreviewCard({required this.onSeeAll});

  (IconData, Color) _iconFor(String type) => switch (type) {
        'product_approved' =>
          (Icons.check_circle_outline, AppColors.success),
        'product_rejected' => (Icons.cancel_outlined, AppColors.error),
        'product_needs_edit' =>
          (Icons.edit_outlined, AppColors.warning),
        'account_approved' =>
          (Icons.account_circle_outlined, AppColors.success),
        _ => (Icons.campaign_outlined, AppColors.primaryContainer),
      };

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CustomerNotificationsController>()) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: const AppEmptyWidget(
          message: 'Henüz bildirim yok.',
          icon: Icons.notifications_none,
        ),
      );
    }

    final ctrl = Get.find<CustomerNotificationsController>();
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
            child: AppLoading(),
          );
        }

        return Column(
          children: [
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                child: AppEmptyWidget(
                  message: 'Henüz bildirim yok.',
                  icon: Icons.notifications_none,
                ),
              )
            else
              ...items.map((n) {
                final (icon, color) = _iconFor(n.type);
                return Column(
                  children: [
                    InkWell(
                      onTap: () =>
                          context.push('/customer/notifications'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(icon,
                                  size: 16, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: n.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
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
                    if (n != items.last)
                      const Divider(
                          height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }),
            const Divider(height: 1, thickness: 1),
            InkWell(
              onTap: onSeeAll,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md)),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_ios,
                        size: 13,
                        color: AppColors.primaryContainer),
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
