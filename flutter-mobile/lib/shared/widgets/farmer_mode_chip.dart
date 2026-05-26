import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

/// Farmer-only mode toggle chip.
///
/// - Farmer NOT in customer-browse mode → "Pazara Göz At" (enters browse mode)
/// - Farmer in customer-browse mode     → "Panele Dön"   (exits browse mode)
/// - Non-farmer                         → invisible (SizedBox.shrink)
///
/// Used in:
///   • FarmerDashboardScreen AppBar actions (primary placement)
///   • HomeScreen AppBar leading (when farmer is browsing as customer)
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
        return ActionChip(
          avatar: const Icon(
            Icons.agriculture,
            size: 16,
            color: AppColors.onPrimaryContainer,
          ),
          label: const Text('Panele Dön'),
          onPressed: () {
            auth.exitCustomerMode();
            context.go('/farmer/dashboard');
          },
          backgroundColor: AppColors.primaryContainer,
          labelStyle: const TextStyle(
            color: AppColors.onPrimaryContainer,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        );
      }

      return ActionChip(
        avatar: const Icon(
          Icons.storefront_outlined,
          size: 16,
          color: AppColors.onSecondaryContainer,
        ),
        label: const Text('Pazara Göz At'),
        onPressed: () {
          auth.enterCustomerMode();
          context.go('/');
        },
        backgroundColor: AppColors.secondaryContainer,
        labelStyle: const TextStyle(
          color: AppColors.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );
    });
  }
}
