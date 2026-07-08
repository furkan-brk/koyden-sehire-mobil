import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

/// KPI stat card used on the admin dashboard.
///
/// Visual improvements over the original:
/// - Coloured left-edge accent strip (4 px, rounded right side).
/// - Icon badge uses a softer tinted background.
/// - Larger, bolder value headline.
/// - Trend badge uses success green consistently.
class AdminStatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final String? trend;
  final Color? color;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.trend,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? AppColors.primary;

    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Coloured left accent strip ─────────────────────────
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
              // ── Card body ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ── Icon badge ───────────────────────────
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 16, color: c),
                          ),
                        ],
                      ),
                      // ── Big number ───────────────────────────────
                      Text(
                        value.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                        // ── Trend badge (optional) ───────────────────
                        if (trend != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 13,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  trend!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
