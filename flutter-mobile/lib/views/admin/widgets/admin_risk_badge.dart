import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

class AdminRiskBadge extends StatelessWidget {
  final String level;
  const AdminRiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (level) {
      'low' => ('Düşük', AppColors.success.withValues(alpha: 0.15), AppColors.success),
      'medium' => ('Orta', AppColors.warning.withValues(alpha: 0.15), AppColors.warning),
      'high' => ('Yüksek', AppColors.error.withValues(alpha: 0.15), AppColors.error),
      _ => (level, AppColors.outlineVariant, AppColors.onSurfaceVariant),
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
