import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

class AdminStatusBadge extends StatelessWidget {
  final String status;
  const AdminStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'pending' => ('Bekliyor', AppColors.warning.withValues(alpha: 0.15), AppColors.warning),
      'approved' || 'active' => ('Onaylı', AppColors.success.withValues(alpha: 0.15), AppColors.success),
      'rejected' => ('Reddedildi', AppColors.error.withValues(alpha: 0.15), AppColors.error),
      'needs_video' => ('Video Gerekli', AppColors.warning.withValues(alpha: 0.15), AppColors.warning),
      'hidden' || 'passive' => ('Gizli', AppColors.outlineVariant, AppColors.onSurfaceVariant),
      'suspended' => ('Askıda', AppColors.error.withValues(alpha: 0.15), AppColors.error),
      _ => (status, AppColors.outlineVariant, AppColors.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
