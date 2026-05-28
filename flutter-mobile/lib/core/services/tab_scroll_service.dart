import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Lightweight registry that lets bottom-nav tabs scroll their currently
/// visible screen back to the top when the user re-taps the active tab.
///
/// Screens register their primary [ScrollController] in `initState` under a
/// stable key (e.g. `'customer.home'`) and unregister it in `dispose`. The
/// bottom nav widget calls [scrollToTop] for the active tab's key.
class TabScrollService extends GetxService {
  final Map<String, ScrollController> _controllers = {};

  void register(String key, ScrollController controller) {
    _controllers[key] = controller;
  }

  void unregister(String key, ScrollController controller) {
    final current = _controllers[key];
    // Only remove if the registered controller is the same instance — guards
    // against an out-of-order dispose after a hot-reload swap.
    if (identical(current, controller)) {
      _controllers.remove(key);
    }
  }

  /// Animates the registered controller (if any) back to offset 0. Returns
  /// true if a controller was found and scrolled.
  bool scrollToTop(String key) {
    final c = _controllers[key];
    if (c == null || !c.hasClients) return false;
    c.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
    return true;
  }
}

/// Well-known keys used across the app. Defined as constants so screens
/// and bottom navs stay in sync.
class TabScrollKeys {
  TabScrollKeys._();

  // Customer tabs
  static const String customerHome = 'customer.home';
  static const String customerMarket = 'customer.market';
  static const String customerProducers = 'customer.producers';
  static const String customerFavorites = 'customer.favorites';
  static const String customerProfile = 'customer.profile';

  // Farmer tabs
  static const String farmerDashboard = 'farmer.dashboard';
  static const String farmerProducts = 'farmer.products';
  static const String farmerInvites = 'farmer.invites';
  static const String farmerProfile = 'farmer.profile';
}
