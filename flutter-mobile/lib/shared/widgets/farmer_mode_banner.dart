import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/router.dart';
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
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          left: false,
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Müşteri modundasınız',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ReturnButton(
                  onPressed: () {
                    auth.exitCustomerMode();
                    AppRouter.router.go('/farmer/dashboard');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ReturnButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ReturnButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                'Panele Dön',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
