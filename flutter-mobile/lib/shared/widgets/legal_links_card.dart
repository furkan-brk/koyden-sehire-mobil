import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';

/// Profil ekranlarında KVKK aydınlatma metni ve kullanım şartları linklerini
/// gösteren kart. Metinler invite-web/ statik sitesinde taslak olarak
/// barındırılıyor (bkz. AppConstants.kvkkUrl / termsUrl).
class LegalLinksCard extends StatelessWidget {
  const LegalLinksCard({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          _LegalRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Gizlilik (KVKK)',
            onTap: () => _open(AppConstants.kvkkUrl),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _LegalRow(
            icon: Icons.description_outlined,
            label: 'Kullanım Şartları',
            onTap: () => _open(AppConstants.termsUrl),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _LegalRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isLast ? Radius.zero : const Radius.circular(AppRadius.md),
        bottom: isLast ? const Radius.circular(AppRadius.md) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.open_in_new, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
