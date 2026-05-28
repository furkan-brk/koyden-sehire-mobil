import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/views/admin/admin_application_detail_view.dart';
import 'package:koyden_sehire/views/admin/admin_applications_view.dart';
import 'package:koyden_sehire/views/admin/admin_audit_log_view.dart';
import 'package:koyden_sehire/views/admin/admin_categories_view.dart';
import 'package:koyden_sehire/views/admin/admin_dashboard_view.dart';
import 'package:koyden_sehire/views/admin/admin_farmer_detail_view.dart';
import 'package:koyden_sehire/views/admin/admin_farmers_view.dart';
import 'package:koyden_sehire/views/admin/admin_invite_network_view.dart';
import 'package:koyden_sehire/views/admin/admin_map_view.dart';
import 'package:koyden_sehire/views/admin/admin_product_detail_view.dart';
import 'package:koyden_sehire/views/admin/admin_products_view.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_shell.dart';
import 'package:koyden_sehire/views/auth/admin_login_screen.dart';
import 'package:koyden_sehire/views/auth/customer_register_screen.dart';
import 'package:koyden_sehire/views/auth/login_screen.dart';
import 'package:koyden_sehire/views/auth/register_choice_screen.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/views/farmer_application/application_form_screen.dart';
import 'package:koyden_sehire/views/farmer_application/application_success_screen.dart';
import 'package:koyden_sehire/views/farmer_application/invite_entry_screen.dart';
import 'package:koyden_sehire/views/farmer/farmer_dashboard_screen.dart';
import 'package:koyden_sehire/views/farmer/invitations_screen.dart';
import 'package:koyden_sehire/views/farmer/my_products_screen.dart';
import 'package:koyden_sehire/views/farmer/product_form_screen.dart';
import 'package:koyden_sehire/views/farmer/farmer_notifications_screen.dart';
import 'package:koyden_sehire/views/farmer/farmer_profile_edit_screen.dart';
import 'package:koyden_sehire/views/farmer/farmer_profile_screen.dart';
import 'package:koyden_sehire/views/otp/otp_screen.dart';
import 'package:koyden_sehire/views/public/public_farmer_profile_screen.dart';
import 'package:koyden_sehire/views/public/home_screen.dart';
import 'package:koyden_sehire/views/public/product_detail_screen.dart';
import 'package:koyden_sehire/views/public/favorites_screen.dart';
import 'package:koyden_sehire/views/public/product_list_screen.dart';
import 'package:koyden_sehire/views/public/product_category_screen.dart';
import 'package:koyden_sehire/views/public/producers_list_screen.dart';
import 'package:koyden_sehire/views/customer/customer_notifications_screen.dart';
import 'package:koyden_sehire/views/customer/customer_profile_edit_screen.dart';
import 'package:koyden_sehire/views/customer/customer_profile_screen.dart';
import 'package:koyden_sehire/views/splash/splash_screen.dart';

// Public routes are accessible to logged-out users AND to logged-in
// customers (customers can keep browsing the marketplace).
const _publicRoutes = {
  '/',
  '/products',
  '/producers',
  '/favorites',
  '/search',
  '/apply',
  '/apply/form',
  '/apply/success',
  '/login',
  '/register',
  '/register/customer',
  '/otp',
};

bool _isPublic(String path) {
  if (_publicRoutes.contains(path)) return true;
  if (path.startsWith('/products/')) return true;
  if (path.startsWith('/farmers/')) return true;
  return false;
}

/// Bridges GetX [AuthService.status] (Rx) to GoRouter's refreshListenable.
class _RouterRefreshListenable extends ChangeNotifier {
  late final Worker _worker;
  _RouterRefreshListenable() {
    _worker = ever<AuthStatus>(
      Get.find<AuthService>().status,
      (_) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _worker.dispose();
    super.dispose();
  }
}

class AppRouter {
  AppRouter._();

  static GoRouter? _instance;

  static GoRouter get router => _instance ??= _build();

  static GoRouter _build() {
    final refresh = _RouterRefreshListenable();
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: refresh,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        if (loc == '/splash') return null;

        final auth = Get.find<AuthService>();

        if (auth.status.value == AuthStatus.admin) {
          if (loc.startsWith('/admin')) return null;
          return '/admin/dashboard';
        }

        if (auth.status.value == AuthStatus.farmerActive) {
          if (loc == '/login' || loc == '/login/admin' || loc.startsWith('/register')) {
            return '/farmer/dashboard';
          }
          return null;
        }

        if (auth.status.value == AuthStatus.customerActive) {
          // Customers can browse public marketplace pages, but auth screens
          // should redirect home.
          if (loc == '/login' || loc == '/login/admin' || loc.startsWith('/register')) {
            return '/';
          }
          if (_isPublic(loc)) return null;
          if (loc.startsWith('/customer')) return null;
          if (loc.startsWith('/farmer') || loc.startsWith('/admin')) {
            return '/';
          }
          return null;
        }

        // logged out / unknown → only public routes allowed
        if (loc.startsWith('/farmer') || loc.startsWith('/admin')) {
          return '/login';
        }
        if (_isPublic(loc)) return null;
        // /login/admin is web-only; on mobile the route isn't registered
        // and the errorBuilder handles it. On web it's a public route.
        if (kIsWeb && loc == '/login/admin') return null;
        return '/login';
      },
      errorBuilder: (_, state) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Sayfa bulunamadı: ${state.uri.path}')),
      ),
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        // ── Public tab routes — NoTransitionPage keeps the AppBar visually
        //    static when the user taps BottomNav items.
        GoRoute(
          path: '/',
          pageBuilder: (_, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/products',
          pageBuilder: (_, state) => NoTransitionPage(
            child: ProductListScreen(
              initialCategoryId: state.uri.queryParameters['category_id'],
              initialSearch: state.uri.queryParameters['search'],
            ),
          ),
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (_, state) => const NoTransitionPage(child: FavoritesScreen()),
        ),
        GoRoute(
          path: '/producers',
          pageBuilder: (_, state) => const NoTransitionPage(child: ProducersListScreen()),
        ),
        // ── Public non-tab routes — keep slide transition
        GoRoute(
          path: '/products/categories',
          builder: (_, __) => const ProductCategoryScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (_, state) => ProductListScreen(
            initialSearch: state.uri.queryParameters['q'],
          ),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/farmers/:id',
          builder: (_, state) => FarmerProfileScreen(farmerId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        // Admin login is web-only. On mobile we don't register the route so
        // direct navigation falls through to the global 404.
        if (kIsWeb)
          GoRoute(
            path: '/login/admin',
            builder: (_, __) => const AdminLoginScreen(),
          ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterChoiceScreen(),
        ),
        GoRoute(
          path: '/register/customer',
          builder: (_, __) => const CustomerRegisterScreen(),
        ),
        GoRoute(
          path: '/admin',
          redirect: (_, __) => '/admin/dashboard',
        ),
        // Admin panel (ShellRoute — ortak Drawer navigasyonu)
        ShellRoute(
          builder: (ctx, state, child) => AdminShell(
            currentLocation: state.matchedLocation,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminDashboardView()),
            ),
            GoRoute(
              path: '/admin/applications',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminApplicationsView()),
            ),
            GoRoute(
              path: '/admin/applications/:id',
              pageBuilder: (_, state) => NoTransitionPage(
                child: AdminApplicationDetailView(appId: state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/admin/products',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminProductsView()),
            ),
            GoRoute(
              path: '/admin/products/:id',
              pageBuilder: (_, state) => NoTransitionPage(
                child: AdminProductDetailView(productId: state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/admin/categories',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminCategoriesView()),
            ),
            GoRoute(
              path: '/admin/farmers',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminFarmersView()),
            ),
            GoRoute(
              path: '/admin/farmers/:id',
              pageBuilder: (_, state) => NoTransitionPage(
                child: AdminFarmerDetailView(farmerId: state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/admin/map',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminMapView()),
            ),
            GoRoute(
              path: '/admin/invite-network',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminInviteNetworkView()),
            ),
            GoRoute(
              path: '/admin/audit-logs',
              pageBuilder: (_, __) => const NoTransitionPage(child: AdminAuditLogView()),
            ),
          ],
        ),
        GoRoute(
          path: '/otp',
          builder: (_, state) => OtpScreen(
            phone: state.uri.queryParameters['phone'] ?? '',
          ),
        ),
        // Application flow
        GoRoute(
          path: '/apply',
          builder: (_, state) => InviteEntryScreen(
            prefillCode: state.uri.queryParameters['invite'],
          ),
        ),
        GoRoute(
          path: '/apply/form',
          builder: (_, __) => const ApplicationFormScreen(),
        ),
        GoRoute(
          path: '/apply/success',
          builder: (_, __) => const ApplicationSuccessScreen(),
        ),
        // ── Farmer tab routes — NoTransitionPage keeps AppBar static
        GoRoute(
          path: '/farmer/dashboard',
          pageBuilder: (_, state) => const NoTransitionPage(child: FarmerDashboardScreen()),
        ),
        GoRoute(
          path: '/farmer/products',
          pageBuilder: (_, state) => const NoTransitionPage(child: MyProductsScreen()),
        ),
        GoRoute(
          path: '/farmer/invites',
          pageBuilder: (_, state) => const NoTransitionPage(child: InvitationsScreen()),
        ),
        GoRoute(
          path: '/farmer/profile',
          pageBuilder: (_, state) => const NoTransitionPage(child: FarmerProfileMainScreen()),
        ),
        GoRoute(
          path: '/farmer/profile/edit',
          builder: (_, __) => const FarmerProfileEditScreen(),
        ),
        // ── Farmer non-tab routes — keep slide transition
        GoRoute(
          path: '/farmer/products/new',
          builder: (_, __) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/farmer/products/:id/edit',
          builder: (_, state) => ProductFormScreen(editingId: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/farmer/notifications',
          pageBuilder: (_, state) => const NoTransitionPage(child: FarmerNotificationsScreen()),
        ),
        // ── Customer panel
        // Legacy redirect — old links still target this path.
        GoRoute(
          path: '/customer/favorites',
          redirect: (_, __) => '/favorites',
        ),
        GoRoute(
          path: '/customer/profile',
          pageBuilder: (_, state) => const NoTransitionPage(child: CustomerProfileScreen()),
        ),
        GoRoute(
          path: '/customer/profile/edit',
          builder: (_, __) => const CustomerProfileEditScreen(),
        ),
        GoRoute(
          path: '/customer/notifications',
          pageBuilder: (_, state) => const NoTransitionPage(child: CustomerNotificationsScreen()),
        ),
      ],
    );
  }
}
