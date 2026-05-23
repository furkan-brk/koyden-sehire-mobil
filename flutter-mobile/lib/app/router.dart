import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/views/admin/admin_application_detail_view.dart';
import 'package:koyden_sehire/views/admin/admin_applications_view.dart';
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
import 'package:koyden_sehire/views/farmer/farmer_profile_edit_screen.dart';
import 'package:koyden_sehire/views/otp/otp_screen.dart';
import 'package:koyden_sehire/views/public/public_farmer_profile_screen.dart';
import 'package:koyden_sehire/views/public/home_screen.dart';
import 'package:koyden_sehire/views/public/product_detail_screen.dart';
import 'package:koyden_sehire/views/public/product_list_screen.dart';
import 'package:koyden_sehire/views/public/basket_screen.dart';
import 'package:koyden_sehire/views/public/producers_list_screen.dart';
import 'package:koyden_sehire/views/customer/customer_profile_screen.dart';
import 'package:koyden_sehire/views/splash/splash_screen.dart';

// Public routes are accessible to logged-out users AND to logged-in
// customers (customers can keep browsing the marketplace).
const _publicRoutes = {
  '/',
  '/products',
  '/producers',
  '/search',
  '/apply',
  '/apply/form',
  '/apply/success',
  '/login',
  '/register',
  '/register/customer',
  '/otp',
  '/basket',
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
          if (loc == '/login' ||
              loc == '/login/admin' ||
              loc.startsWith('/register')) {
            return '/farmer/dashboard';
          }
          return null;
        }

        if (auth.status.value == AuthStatus.customerActive) {
          // Customers can browse public marketplace pages, but auth screens
          // should redirect home.
          if (loc == '/login' ||
              loc == '/login/admin' ||
              loc.startsWith('/register')) {
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
        GoRoute(
          path: '/',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/products',
          builder: (_, state) => ProductListScreen(
            initialCategoryId: state.uri.queryParameters['category_id'],
            initialSearch: state.uri.queryParameters['search'],
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, state) => ProductListScreen(
            initialSearch: state.uri.queryParameters['q'],
          ),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (_, state) =>
              ProductDetailScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/farmers/:id',
          builder: (_, state) =>
              FarmerProfileScreen(farmerId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/basket',
          builder: (_, __) => const BasketScreen(),
        ),
        GoRoute(
          path: '/producers',
          builder: (_, __) => const ProducersListScreen(),
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
          path: '/customer/profile',
          builder: (_, __) => const CustomerProfileScreen(),
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
              builder: (_, __) => const AdminDashboardView(),
            ),
            GoRoute(
              path: '/admin/applications',
              builder: (_, __) => const AdminApplicationsView(),
            ),
            GoRoute(
              path: '/admin/applications/:id',
              builder: (_, state) => AdminApplicationDetailView(
                appId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/admin/products',
              builder: (_, __) => const AdminProductsView(),
            ),
            GoRoute(
              path: '/admin/products/:id',
              builder: (_, state) => AdminProductDetailView(
                productId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/admin/categories',
              builder: (_, __) => const AdminCategoriesView(),
            ),
            GoRoute(
              path: '/admin/farmers',
              builder: (_, __) => const AdminFarmersView(),
            ),
            GoRoute(
              path: '/admin/farmers/:id',
              builder: (_, state) => AdminFarmerDetailView(
                farmerId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/admin/map',
              builder: (_, __) => const AdminMapView(),
            ),
            GoRoute(
              path: '/admin/invite-network',
              builder: (_, __) => const AdminInviteNetworkView(),
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
        // Farmer panel
        GoRoute(
          path: '/farmer/dashboard',
          builder: (_, __) => const FarmerDashboardScreen(),
        ),
        GoRoute(
          path: '/farmer/profile',
          builder: (_, __) => const FarmerProfileEditScreen(),
        ),
        GoRoute(
          path: '/farmer/products',
          builder: (_, __) => const MyProductsScreen(),
        ),
        GoRoute(
          path: '/farmer/products/new',
          builder: (_, __) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/farmer/products/:id/edit',
          builder: (_, state) =>
              ProductFormScreen(editingId: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/farmer/invites',
          builder: (_, __) => const InvitationsScreen(),
        ),
        // Customer panel
        GoRoute(
          path: '/customer/profile',
          builder: (_, __) => const CustomerProfileScreen(),
        ),
      ],
    );
  }
}
