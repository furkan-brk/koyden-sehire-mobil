import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/models/farmer_profile_edit_model.dart';
import 'package:koyden_sehire/shared/utils/confirm_dialog.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/legal_links_card.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';
import 'package:koyden_sehire/controllers/farmer/dashboard_controller.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_notifications_controller.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';

class FarmerProfileMainScreen extends StatelessWidget {
  const FarmerProfileMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<FarmerProfileController>();
    final dashCtrl = Get.find<DashboardController>();
    final notifsCtrl = Get.find<FarmerNotificationsController>();

    Future<void> confirmLogout() async {
      final ok = await showConfirmDialog(
        context,
        title: 'Çıkış Yap',
        message: 'Hesabınızdan çıkmak istediğinize emin misiniz?',
        confirmLabel: 'Çıkış Yap',
        isDestructive: true,
      );
      if (!ok) return;
      await Get.find<AuthService>().logout();
      if (context.mounted) context.go('/');
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profilim'),
      ),
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.profile),
      body: Obx(() {
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
            // ── Profil başlık kartı ─────────────────────────────────────
            _FarmerProfileHeaderCard(profile: p),
            const SizedBox(height: 16),

            // ── İstatistikler ───────────────────────────────────────────
            _StatsRow(dashCtrl: dashCtrl),
            const SizedBox(height: 24),

            // ── Profil Bilgileri tıklanabilir kart ──────────────────────
            const _SectionHeader(
              icon: Icons.storefront_outlined,
              title: 'Profil Bilgileri',
            ),
            const SizedBox(height: 10),
            _ProfileInfoCard(
              onTap: () => context.push('/farmer/profile/edit'),
            ),
            const SizedBox(height: 24),

            // ── Bildirimler ─────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.notifications_outlined,
              title: 'Bildirimler',
              trailing: Obx(() {
                final count = notifsCtrl.unreadCount.value;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ctrl: notifsCtrl,
              onSeeAll: () => context.push('/farmer/notifications'),
            ),
            const SizedBox(height: 24),

            // ── Yasal ───────────────────────────────────────────────────
            const _SectionHeader(
              icon: Icons.gavel_outlined,
              title: 'Yasal',
            ),
            const SizedBox(height: 10),
            const LegalLinksCard(),
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
              onLogout: confirmLogout,
            ),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Çiftçi profil başlık kartı
// ─────────────────────────────────────────────────────────────────────────────

class _FarmerProfileHeaderCard extends StatelessWidget {
  final FarmerProfileEdit profile;
  const _FarmerProfileHeaderCard({required this.profile});

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
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.secondaryContainer,
            backgroundImage: profile.profileImageUrl == null
                ? null
                : CachedNetworkImageProvider(profile.profileImageUrl!),
            child: profile.profileImageUrl == null
                ? Icon(Icons.person, size: 32, color: cs.primaryContainer)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  producerTypeLabels[profile.producerType] ??
                      profile.producerType ??
                      '',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                if (profile.city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.city,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Üretici Hesabı',
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

// ─────────────────────────────────────────────────────────────────────────────
// Profil Bilgileri tıklanabilir kart
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileInfoCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileInfoCard({required this.onTap});

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
                child: Icon(Icons.storefront_outlined,
                    size: 18, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profil Bilgileri',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Çiftlik adı, konum ve biyografi bilgilerinizi düzenleyin.',
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
                  color: color),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
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
        'account_approved' =>
          (Icons.account_circle_outlined, AppColors.success),
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
                    Icon(Icons.notifications_none,
                        color: AppColors.onSurfaceVariant, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Henüz bildiriminiz yok',
                      style: TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                              child:
                                  Icon(icon, size: 16, color: color),
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_ios,
                        size: 13, color: AppColors.primaryContainer),
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
                const Icon(Icons.phone_outlined,
                    color: AppColors.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İletişim Telefonu',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11),
                      ),
                      Text(
                        profile.publicPhone.isEmpty
                            ? '-'
                            : PhoneFormatter.pretty(profile.publicPhone),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
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
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.md)),
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
