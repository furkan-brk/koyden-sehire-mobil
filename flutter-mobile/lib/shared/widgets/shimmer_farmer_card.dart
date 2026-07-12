import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:koyden_sehire/app/theme.dart';

/// Skeleton placeholder matching [FarmerCard]'s proportions (avatar + name +
/// location + badge) for loading states in farmer lists.
class ShimmerFarmerCard extends StatelessWidget {
  final double? width;
  const ShimmerFarmerCard({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerLow;
    final highlight = cs.surfaceContainerHigh;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: base,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: 14,
                width: 100,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 11,
                width: 80,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: 18,
                width: 64,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
