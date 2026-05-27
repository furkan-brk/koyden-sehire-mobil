import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const AdminShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
            onPressed: () => Get.find<AuthService>().logout(),
          ),
        ],
      ),
      drawer: _AdminDrawer(currentLocation: currentLocation),
      body: child,
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final String currentLocation;
  const _AdminDrawer({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text(
                  'Köyden Şehre',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                Text(
                  'Admin Paneli',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/admin/dashboard',
                  currentLocation: currentLocation,
                ),
                _NavItem(
                  icon: Icons.assignment_outlined,
                  label: 'Başvurular',
                  route: '/admin/applications',
                  currentLocation: currentLocation,
                ),
                _NavItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Ürün Moderasyonu',
                  route: '/admin/products',
                  currentLocation: currentLocation,
                ),
                _NavItem(
                  icon: Icons.category_outlined,
                  label: 'Kategoriler',
                  route: '/admin/categories',
                  currentLocation: currentLocation,
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  label: 'Üreticiler',
                  route: '/admin/farmers',
                  currentLocation: currentLocation,
                ),
                _NavItem(
                  icon: Icons.map_outlined,
                  label: 'Şehir Yoğunluğu',
                  route: '/admin/map',
                  currentLocation: currentLocation,
                ),
                _NavItem(
                  icon: Icons.account_tree_outlined,
                  label: 'Davet Ağı',
                  route: '/admin/invite-network',
                  currentLocation: currentLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = currentLocation.startsWith(route);
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? cs.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? cs.primary : null,
        ),
      ),
      selected: isActive,
      selectedTileColor: cs.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        context.go(route);
        Navigator.of(context).pop();
      },
    );
  }
}
