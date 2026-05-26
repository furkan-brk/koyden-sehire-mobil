// TODO: Bildirim API hazır olduğunda burada gerçek bildirimler gösterilecek.
import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';

class FarmerNotificationsScreen extends StatelessWidget {
  const FarmerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimlerim')),
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.profile),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 48,
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz bildiriminiz yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Ürün onayları, başvuru durumu ve platform duyuruları burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Yakında gelecek bildirim tipleri — preview/pasif görünüm
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İleride burada neler göreceksiniz?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 10),
                  _PreviewNotificationTile(
                    icon: Icons.check_circle_outline,
                    text: 'Ürününüz onaylandı',
                    color: AppColors.success,
                  ),
                  SizedBox(height: 8),
                  _PreviewNotificationTile(
                    icon: Icons.cancel_outlined,
                    text: 'Ürününüz reddedildi',
                    color: AppColors.error,
                  ),
                  SizedBox(height: 8),
                  _PreviewNotificationTile(
                    icon: Icons.campaign_outlined,
                    text: 'Platform duyurusu',
                    color: AppColors.primaryContainer,
                  ),
                  SizedBox(height: 8),
                  _PreviewNotificationTile(
                    icon: Icons.account_circle_outlined,
                    text: 'Hesap ve başvuru bildirimleri',
                    color: AppColors.primaryContainer,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bu bildirim türleri yakında aktif olacak.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PreviewNotificationTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _PreviewNotificationTile({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
