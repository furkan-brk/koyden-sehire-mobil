import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/controllers/farmer/farmer_notifications_controller.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/tab_scroll_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';

enum FarmerTab { dashboard, products, invites, profile }

const _farmerTabKeys = <FarmerTab, String>{
  FarmerTab.dashboard: TabScrollKeys.farmerDashboard,
  FarmerTab.products: TabScrollKeys.farmerProducts,
  FarmerTab.invites: TabScrollKeys.farmerInvites,
  FarmerTab.profile: TabScrollKeys.farmerProfile,
};

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
                ? const Semantics(
                    label: 'Hesap askıda — bu sekme kullanılamıyor',
                    excludeSemantics: true,
                    child: Opacity(
                      opacity: 0.4,
                      child: Icon(Icons.shopping_bag_outlined),
                    ),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            selectedIcon: isSuspended
                ? const Semantics(
                    label: 'Hesap askıda — bu sekme kullanılamıyor',
                    excludeSemantics: true,
                    child: Opacity(
                      opacity: 0.4,
                      child: Icon(Icons.shopping_bag),
                    ),
                  )
                : const Icon(Icons.shopping_bag),
            label: 'Ürünlerim',
          ),
          NavigationDestination(
            icon: isSuspended
                ? const Semantics(
                    label: 'Hesap askıda — bu sekme kullanılamıyor',
                    excludeSemantics: true,
                    child: Opacity(
                      opacity: 0.4,
                      child: Icon(Icons.card_giftcard_outlined),
                    ),
                  )
                : const Icon(Icons.card_giftcard_outlined),
            selectedIcon: isSuspended
                ? const Semantics(
                    label: 'Hesap askıda — bu sekme kullanılamıyor',
                    excludeSemantics: true,
                    child: Opacity(
                      opacity: 0.4,
                      child: Icon(Icons.card_giftcard),
                    ),
                  )
                : const Icon(Icons.card_giftcard),
            label: 'Davetler',
          ),
          const NavigationDestination(
            icon: _FarmerProfileTabIcon(icon: Icons.person_outline),
            selectedIcon: _FarmerProfileTabIcon(icon: Icons.person),
            label: 'Profil',
          ),
        ],
      );
    });
  }

  void _navigate(BuildContext context, int i, bool isSuspended) {
    // Re-tap on the active tab → scroll the current screen back to the top.
    if (i == current.index) {
      final key = _farmerTabKeys[current];
      if (key != null && Get.isRegistered<TabScrollService>()) {
        Get.find<TabScrollService>().scrollToTop(key);
      }
      return;
    }
    if (isSuspended && (i == FarmerTab.products.index || i == FarmerTab.invites.index)) {
      context.snack('Hesabınız askıya alınmıştır.', isError: true);
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

/// Farmer profile tab icon decorated with the unread-notifications badge.
class _FarmerProfileTabIcon extends StatelessWidget {
  final IconData icon;
  const _FarmerProfileTabIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<FarmerNotificationsController>()) {
      return Icon(icon);
    }
    final c = Get.find<FarmerNotificationsController>();
    return Obx(() {
      final unread = c.unreadCount.value;
      if (unread <= 0) return Icon(icon);
      return Badge(
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(icon),
      );
    });
  }
}
