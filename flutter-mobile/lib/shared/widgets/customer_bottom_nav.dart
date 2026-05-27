import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

/// Customer bottom navigation tabs.
///
/// [home] → `/` (HomeScreen, landing with hero/categories/featured)
/// [market] → `/products` (ProductListScreen, full searchable catalogue)
/// [producers] → `/producers`
/// [favorites] → `/favorites`
/// [profile] → `/customer/profile` (or /login when logged out)
enum CustomerTab { home, market, producers, favorites, profile }

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
            icon: Icon(isCustomer ? Icons.person_outline : Icons.login_outlined),
            selectedIcon: Icon(isCustomer ? Icons.person : Icons.login),
            label: isCustomer ? 'Profil' : 'Giriş',
          ),
        ],
      );
    });
  }

  void _navigate(BuildContext context, int i) {
    if (i == current.index) return;
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
          context.go('/login');
        }
    }
  }
}
