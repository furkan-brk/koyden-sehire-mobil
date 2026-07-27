import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/controllers/customer/customer_notifications_controller.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/tab_scroll_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

/// Customer bottom navigation tabs.
///
/// [home] → `/` (HomeScreen, landing with hero/categories/featured)
/// [market] → `/products` (ProductListScreen, full searchable catalogue)
/// [producers] → `/producers`
/// [favorites] → `/favorites`
/// [profile] → `/customer/profile` (or /login when logged out)
enum CustomerTab { home, market, producers, favorites, profile }

const _customerTabKeys = <CustomerTab, String>{
  CustomerTab.home: TabScrollKeys.customerHome,
  CustomerTab.market: TabScrollKeys.customerMarket,
  CustomerTab.producers: TabScrollKeys.customerProducers,
  CustomerTab.favorites: TabScrollKeys.customerFavorites,
  CustomerTab.profile: TabScrollKeys.customerProfile,
};

class CustomerBottomNav extends StatelessWidget {
  final CustomerTab current;
  const CustomerBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      final isCustomer = auth.status.value == AuthStatus.customerActive ||
          (auth.status.value == AuthStatus.farmerActive &&
              auth.isBrowsingAsCustomer.value);
      return NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Market',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Üreticiler',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoriler',
          ),
          NavigationDestination(
            icon: _ProfileTabIcon(
              icon: isCustomer ? Icons.person_outline : Icons.login_outlined,
              showBadge: isCustomer,
            ),
            selectedIcon: _ProfileTabIcon(
              icon: isCustomer ? Icons.person : Icons.login,
              showBadge: isCustomer,
            ),
            label: isCustomer ? 'Profil' : 'Giriş',
          ),
        ],
      );
    });
  }

  void _navigate(BuildContext context, int i) {
    // Re-tap on the active tab → scroll the current screen back to the top.
    if (i == current.index) {
      final key = _customerTabKeys[current];
      if (key != null && Get.isRegistered<TabScrollService>()) {
        Get.find<TabScrollService>().scrollToTop(key);
      }
      return;
    }
    final auth = Get.find<AuthService>();
    final isFarmerBrowsing = auth.status.value == AuthStatus.farmerActive &&
        auth.isBrowsingAsCustomer.value;
    final isCustomer = auth.status.value == AuthStatus.customerActive;
    switch (i) {
      case 0:
        context.go('/');
      case 1:
        context.go('/products');
      case 2:
        context.go('/producers');
      case 3:
        context.go('/favorites');
      case 4:
        if (isFarmerBrowsing) {
          context.push('/farmer/profile');
        } else if (isCustomer) {
          context.go('/customer/profile');
        } else {
          // push: giriş ekranında geri okunun çıkması için yığın korunur
          context.push('/login');
        }
    }
  }
}

/// Profile tab icon decorated with the unread-notifications [Badge].
///
/// We resolve the count lazily so that signed-out users (who never
/// instantiate the CustomerNotificationsController) don't pay a cost here.
class _ProfileTabIcon extends StatelessWidget {
  final IconData icon;
  final bool showBadge;
  const _ProfileTabIcon({required this.icon, required this.showBadge});

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return Icon(icon);
    if (!Get.isRegistered<CustomerNotificationsController>()) {
      return Icon(icon);
    }
    final c = Get.find<CustomerNotificationsController>();
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
