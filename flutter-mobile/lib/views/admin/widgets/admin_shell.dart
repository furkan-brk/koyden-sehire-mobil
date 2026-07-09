import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';

const double _kDesktopBreak = 1100;
const double _kSidebarWidth = 232;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kDesktopBreak) {
          return _DesktopLayout(currentLocation: currentLocation, child: child);
        }
        return _MobileLayout(currentLocation: currentLocation, child: child);
      },
    );
  }
}

// ── Desktop ────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  const _DesktopLayout({required this.child, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(currentLocation: currentLocation),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(currentLocation: currentLocation),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  final String currentLocation;
  const _AdminTopBar({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            _routeTitle(currentLocation),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const Spacer(),
          _AdminBadge(),
          const SizedBox(width: 8),
          _LogoutButton(),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            'Admin',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout_outlined, size: 18),
      tooltip: 'Çıkış Yap',
      color: AppColors.onSurfaceVariant,
      onPressed: () => Get.find<AuthService>().logout(),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final String currentLocation;
  const _AdminSidebar({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kSidebarWidth,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          border: Border(
            right: BorderSide(
              color: Color(0x22000000),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
                  const SizedBox(height: 8),
                  Text(
                    'Köyden Şehre',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    'Yönetim Paneli',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1, thickness: 1),
            const SizedBox(height: 6),
            // Nav
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    _SidebarItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      route: '/admin/dashboard',
                      currentLocation: currentLocation,
                    ),
                    _SidebarItem(
                      icon: Icons.assignment_outlined,
                      label: 'Başvurular',
                      route: '/admin/applications',
                      currentLocation: currentLocation,
                    ),
                    _SidebarItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Ürün Moderasyonu',
                      route: '/admin/products',
                      currentLocation: currentLocation,
                    ),
                    _SidebarItem(
                      icon: Icons.category_outlined,
                      label: 'Kategoriler',
                      route: '/admin/categories',
                      currentLocation: currentLocation,
                    ),
                    _SidebarItem(
                      icon: Icons.people_outline,
                      label: 'Üreticiler',
                      route: '/admin/farmers',
                      currentLocation: currentLocation,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentLocation;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentLocation.startsWith(route);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isActive
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          splashColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                if (isActive)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  const SizedBox(width: 11),
                Icon(
                  icon,
                  size: 17,
                  color: isActive ? Colors.white : Colors.white60,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mobile ─────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  const _MobileLayout({required this.child, required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_routeTitle(currentLocation)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
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
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.eco_rounded, color: Colors.white, size: 32),
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
                _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', route: '/admin/dashboard', currentLocation: currentLocation),
                _NavItem(icon: Icons.assignment_outlined, label: 'Başvurular', route: '/admin/applications', currentLocation: currentLocation),
                _NavItem(icon: Icons.inventory_2_outlined, label: 'Ürün Moderasyonu', route: '/admin/products', currentLocation: currentLocation),
                _NavItem(icon: Icons.category_outlined, label: 'Kategoriler', route: '/admin/categories', currentLocation: currentLocation),
                _NavItem(icon: Icons.people_outline, label: 'Üreticiler', route: '/admin/farmers', currentLocation: currentLocation),
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
      leading: Icon(icon, color: isActive ? cs.primary : null),
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

// ── Helpers ────────────────────────────────────────────────────────────────

String _routeTitle(String location) {
  if (location.startsWith('/admin/applications')) return 'Başvurular';
  if (location.startsWith('/admin/products')) return 'Ürün Moderasyonu';
  if (location.startsWith('/admin/categories')) return 'Kategoriler';
  if (location.startsWith('/admin/farmers')) return 'Üreticiler';
  if (location.startsWith('/admin/map')) return 'Şehir Yoğunluğu';
  if (location.startsWith('/admin/invite-network')) return 'Davet Ağı';
  if (location.startsWith('/admin/dashboard')) return 'Dashboard';
  return 'Yönetim Paneli';
}
