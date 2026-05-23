import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

enum PublicTab { home, products, applyOrFavorites, loginOrProfile }

class PublicBottomNav extends StatelessWidget {
  final PublicTab current;
  const PublicBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    return Obx(() {
      final isCustomer = auth.status.value == AuthStatus.customerActive;
      return NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (i) => _navigate(context, i, isCustomer),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Ürünler',
          ),
          NavigationDestination(
            icon: Icon(isCustomer
                ? Icons.favorite_border
                : Icons.agriculture_outlined),
            selectedIcon:
                Icon(isCustomer ? Icons.favorite : Icons.agriculture),
            label: isCustomer ? 'Favoriler' : 'Başvur',
          ),
          NavigationDestination(
            icon: Icon(
                isCustomer ? Icons.person_outline : Icons.login_outlined),
            selectedIcon:
                Icon(isCustomer ? Icons.person : Icons.login),
            label: isCustomer ? 'Profil' : 'Giriş',
          ),
        ],
      );
    });
  }

  void _navigate(BuildContext context, int i, bool isCustomer) {
    if (i == current.index) return;
    switch (i) {
      case 0:
        context.go('/');
      case 1:
        context.go('/products');
      case 2:
        context.go(isCustomer ? '/favorites' : '/apply');
      case 3:
        context.go(isCustomer ? '/customer/profile' : '/login');
    }
  }
}
