import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

enum FarmerTab { dashboard, products, invites, profile }

class FarmerBottomNav extends StatelessWidget {
  final FarmerTab current;
  const FarmerBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      final isSuspended = auth.status.value == AuthStatus.farmerSuspended;
      return NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (i) => _navigate(context, i, isSuspended),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: isSuspended
                ? const Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.shopping_bag_outlined),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            selectedIcon: isSuspended
                ? const Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.shopping_bag),
                  )
                : const Icon(Icons.shopping_bag),
            label: 'Ürünlerim',
          ),
          NavigationDestination(
            icon: isSuspended
                ? const Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.card_giftcard_outlined),
                  )
                : const Icon(Icons.card_giftcard_outlined),
            selectedIcon: isSuspended
                ? const Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.card_giftcard),
                  )
                : const Icon(Icons.card_giftcard),
            label: 'Davetler',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      );
    });
  }

  void _navigate(BuildContext context, int i, bool isSuspended) {
    if (i == current.index) return;
    if (isSuspended && (i == FarmerTab.products.index || i == FarmerTab.invites.index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesabınız askıda. Bu özelliği kullanamazsınız.'),
        ),
      );
      return;
    }
    switch (i) {
      case 0:
        context.go('/farmer/dashboard');
      case 1:
        context.go('/farmer/products');
      case 2:
        context.go('/farmer/invites');
      case 3:
        context.go('/farmer/profile');
    }
  }
}
