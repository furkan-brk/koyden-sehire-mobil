import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

/// Üretici → Pazar modu geçiş chip'i.
/// Farmer girişli olan tüm ekranlarda sol üste yerleştirilir.
class FarmerModeChip extends StatelessWidget {
  const FarmerModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      if (auth.status.value != AuthStatus.farmerActive) {
        return const SizedBox.shrink();
      }
      final isBrowsing = auth.isBrowsingAsCustomer.value;
      return GestureDetector(
        onTap: () => _toggle(context, auth, isBrowsing),
        child: Container(
          margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isBrowsing
                ? AppColors.secondaryContainer
                : AppColors.primaryFixed.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isBrowsing
                  ? AppColors.onSecondaryContainer.withValues(alpha: 0.2)
                  : AppColors.primaryContainer.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBrowsing ? Icons.storefront_outlined : Icons.agriculture_outlined,
                size: 13,
                color: isBrowsing
                    ? AppColors.onSecondaryContainer
                    : AppColors.primaryContainer,
              ),
              const SizedBox(width: 5),
              Text(
                isBrowsing ? 'Pazar Modu' : 'Üretici Modu',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isBrowsing
                      ? AppColors.onSecondaryContainer
                      : AppColors.primaryContainer,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isBrowsing ? Icons.swap_horiz : Icons.swap_horiz,
                size: 12,
                color: isBrowsing
                    ? AppColors.onSecondaryContainer
                    : AppColors.primaryContainer,
              ),
            ],
          ),
        ),
      );
    });
  }

  void _toggle(BuildContext context, AuthService auth, bool isBrowsing) {
    if (isBrowsing) {
      auth.exitCustomerMode();
      context.go('/farmer/dashboard');
    } else {
      auth.enterCustomerMode();
      context.go('/');
    }
  }
}
