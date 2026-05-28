import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

/// Slim banner shown when an active farmer is browsing in customer mode.
///
/// Mounted globally in `app.dart` so it sits above every screen while
/// `AuthService.isBrowsingAsCustomer` is true. Renders [SizedBox.shrink]
/// otherwise — safe to keep in the widget tree unconditionally.
class FarmerModeBanner extends StatelessWidget {
  const FarmerModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      final isFarmer = auth.status.value == AuthStatus.farmerActive;
      if (!isFarmer || !auth.isBrowsingAsCustomer.value) {
        return const SizedBox.shrink();
      }
      return Material(
        color: const Color(0xFFFFB300), // amber 600
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: Colors.black87,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Müşteri modunda geziyorsunuz',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    auth.exitCustomerMode();
                    context.go('/farmer/dashboard');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Çiftçi Paneline Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
