import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

enum StatusKind {
  active,
  pending,
  rejected,
  hidden,
  outOfStock,
  suspended,
}

class StatusBadge extends StatelessWidget {
  final StatusKind kind;
  final String? label;

  const StatusBadge({super.key, required this.kind, this.label});

  /// Maps a raw string status value to a [StatusKind].
  static StatusKind fromString(String status) => switch (status) {
        'active' => StatusKind.active,
        'pending' => StatusKind.pending,
        'rejected' => StatusKind.rejected,
        'hidden' => StatusKind.hidden,
        'out_of_stock' => StatusKind.outOfStock,
        'suspended' => StatusKind.suspended,
        _ => StatusKind.hidden,
      };

  static String _defaultLabel(StatusKind kind) => switch (kind) {
        StatusKind.active => 'Aktif',
        StatusKind.pending => 'Beklemede',
        StatusKind.rejected => 'Reddedildi',
        StatusKind.hidden => 'Gizli',
        StatusKind.outOfStock => 'Tükendi',
        StatusKind.suspended => 'Askıda',
      };

  static Color _color(StatusKind kind) => switch (kind) {
        StatusKind.active => AppColors.success,
        StatusKind.pending => AppColors.warning,
        StatusKind.rejected => AppColors.error,
        StatusKind.hidden => AppColors.onSurfaceVariant,
        StatusKind.outOfStock => const Color(0xFFB45309), // amber-700
        StatusKind.suspended => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(kind);
    final text = label ?? _defaultLabel(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
