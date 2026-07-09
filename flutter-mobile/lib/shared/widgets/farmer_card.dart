import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/shared/widgets/founding_badge.dart';
import 'package:koyden_sehire/shared/widgets/verified_badge.dart';

class FarmerCard extends StatelessWidget {
  final FarmerSummary farmer;

  /// Yatay listelerde sabit genişlik için; null ise (grid tile içinde)
  /// genişliği parent belirler.
  final double? width;

  const FarmerCard({super.key, required this.farmer, this.width});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => context.push('/farmers/${farmer.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.surfaceContainerLow,
                    backgroundImage: farmer.profileImageUrl == null
                        ? null
                        : CachedNetworkImageProvider(farmer.profileImageUrl!),
                    child: farmer.profileImageUrl == null
                        ? Icon(Icons.person, color: cs.onSurfaceVariant)
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    farmer.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${farmer.city}, ${farmer.district}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (farmer.isFoundingFarmer)
                    const FoundingBadge()
                  else if (farmer.isVerified)
                    const VerifiedBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
