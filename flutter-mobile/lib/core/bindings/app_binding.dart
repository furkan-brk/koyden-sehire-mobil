import 'package:get/get.dart';

import 'package:koyden_sehire/controllers/customer/customer_profile_controller.dart';
import 'package:koyden_sehire/core/services/push_notification_service.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/services/auth_repository.dart';
import 'package:koyden_sehire/services/customer_profile_repository.dart';
import 'package:koyden_sehire/services/push_token_repository.dart';
import 'package:koyden_sehire/services/application_repository.dart';
import 'package:koyden_sehire/controllers/application_form_controller.dart';
import 'package:koyden_sehire/services/dashboard_repository.dart';
import 'package:koyden_sehire/controllers/farmer/dashboard_controller.dart';
import 'package:koyden_sehire/services/invitation_repository.dart';
import 'package:koyden_sehire/controllers/farmer/invitation_controller.dart';
import 'package:koyden_sehire/services/farmer_product_repository.dart';
import 'package:koyden_sehire/controllers/farmer/my_products_controller.dart';
import 'package:koyden_sehire/controllers/farmer/product_form_controller.dart';
import 'package:koyden_sehire/services/farmer_profile_repository.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';
import 'package:koyden_sehire/services/otp_repository.dart';
import 'package:koyden_sehire/services/category_repository.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/services/farmer_repository.dart';
import 'package:koyden_sehire/controllers/public/home_controller.dart';
import 'package:koyden_sehire/services/product_repository.dart';
import 'package:koyden_sehire/controllers/public/product_list_controller.dart';
import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/connectivity_service.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/core/storage/secure_storage_service.dart';
import 'package:koyden_sehire/services/favorites_repository.dart';
import 'package:koyden_sehire/services/notification_repository.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_notifications_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Core infra
    final storage = SecureStorageService();
    Get.put<SecureStorageService>(storage, permanent: true);

    final authService = AuthService(storage);
    Get.put<AuthService>(authService, permanent: true);

    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);

    final apiClient = ApiClient(
      storage,
      onUnauthorized: () {
        // ignore: discarded_futures
        Get.find<AuthService>().handleUnauthorized();
      },
    );
    Get.put<ApiClient>(apiClient, permanent: true);

    Get.lazyPut<FavoritesRepository>(
      () => FavoritesRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.put<FavoritesService>(
      FavoritesService(Get.find<FavoritesRepository>()),
      permanent: true,
    );

    Get.lazyPut<PushTokenRepository>(
      () => PushTokenRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.put<PushNotificationService>(
      PushNotificationService(Get.find<PushTokenRepository>()),
      permanent: true,
    );

    // Repositories (lazy + fenix so they re-create after Get.delete)
    Get.lazyPut<AuthRepository>(
      () => AuthRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<CategoryRepository>(
      () => CategoryRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<ProductRepository>(
      () => ProductRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<FarmerRepository>(
      () => FarmerRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<OtpRepository>(
      () => OtpRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<FarmerProductRepository>(
      () => FarmerProductRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<FarmerProfileRepository>(
      () => FarmerProfileRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<DashboardRepository>(
      () => DashboardRepository(
        api: Get.find<ApiClient>(),
        products: Get.find<FarmerProductRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ApplicationRepository>(
      () => ApplicationRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<InvitationRepository>(
      () => InvitationRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<CustomerProfileRepository>(
      () => CustomerProfileRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<AdminRepository>(
      () => AdminRepository(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<NotificationRepository>(
      () => NotificationRepository(Get.find<ApiClient>()),
      fenix: true,
    );

    // Global controllers (lazy + fenix; initialized on first access)
    Get.lazyPut<CategoryController>(
      () => CategoryController(Get.find<CategoryRepository>()),
      fenix: true,
    );
    Get.lazyPut<HomeController>(
      () => HomeController(
        Get.find<ProductRepository>(),
        Get.find<FarmerRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<ProductListController>(
      () => ProductListController(Get.find<ProductRepository>()),
      fenix: true,
    );
    Get.lazyPut<FarmerProfileController>(
      () => FarmerProfileController(
        profileRepo: Get.find<FarmerProfileRepository>(),
        productRepo: Get.find<FarmerProductRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<DashboardController>(
      () => DashboardController(Get.find<DashboardRepository>()),
      fenix: true,
    );
    Get.lazyPut<InvitationController>(
      () => InvitationController(Get.find<InvitationRepository>()),
      fenix: true,
    );
    Get.lazyPut<MyProductsController>(
      () => MyProductsController(Get.find<FarmerProductRepository>()),
      fenix: true,
    );
    Get.lazyPut<ProductFormController>(
      () => ProductFormController(Get.find<FarmerProductRepository>()),
      fenix: true,
    );
    Get.lazyPut<ApplicationFormController>(
      () => ApplicationFormController(Get.find<ApplicationRepository>()),
      fenix: true,
    );
    Get.lazyPut<CustomerProfileController>(
      () => CustomerProfileController(Get.find<CustomerProfileRepository>()),
      fenix: true,
    );
    Get.lazyPut<FarmerNotificationsController>(
      () => FarmerNotificationsController(Get.find<NotificationRepository>()),
      fenix: true,
    );
  }
}
