import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

/// Shown in AppBar leading on public screens and as a subtitle element on the
/// farmer dashboard.
///
/// - Farmer NOT in customer-browse mode → "Pazara Göz At" (enters browse mode)
/// - Farmer in customer-browse mode → "Panele Dön" (exits browse mode)
/// - Non-farmer → empty
class FarmerModeChip extends StatelessWidget {
  const FarmerModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      if (auth.status.value != AuthStatus.farmerActive) {
        return const SizedBox.shrink();
      }

      if (auth.isBrowsingAsCustomer.value) {
        return _chip(
          context,
          icon: Icons.agriculture,
          label: 'Panele Dön',
          color: AppColors.primaryContainer,
          onLabel: AppColors.onPrimary,
          onTap: () {
            auth.exitCustomerMode();
            context.go('/farmer/dashboard');
          },
        );
      }

      return _chip(
        context,
        icon: Icons.storefront_outlined,
        label: 'Pazara Göz At',
        color: AppColors.secondaryContainer,
        onLabel: AppColors.secondary,
        onTap: () {
          auth.enterCustomerMode();
          context.go('/');
        },
      );
    });
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color onLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: onLabel),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: onLabel,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
