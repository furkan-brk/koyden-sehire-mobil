class ApiEndpoints {
  // Public
  static const String health = '/health';
  static const String categories = '/categories';
  static const String products = '/products';
  static const String inviteValidate = '/invites/validate';

  static String productById(String id) => '/products/$id';
  static const String farmers = '/farmers';
  static String farmerById(String id) => '/farmers/$id';
  static String farmerProducts(String farmerId) => '/farmers/$farmerId/products';

  // Auth
  static const String login = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String registerCustomer = '/auth/register/customer';

  // OTP
  static const String otpSend = '/otp/send';
  static const String otpVerify = '/otp/verify';

  // Farmer application
  static const String farmerApplications = '/farmer-applications';
  static const String applicationVideoPresignedUrl =
      '/uploads/application-video/presigned-url';

  // Farmer panel
  static const String farmerProfile = '/farmer/profile';
  static const String farmerProducts2 = '/farmer/products';
  static const String farmerInvites = '/farmer/invites';
  static const String uploadProductImage = '/farmer/uploads/product-image';
  static const String uploadProfileImage = '/farmer/uploads/profile-image';

  static String farmerProduct(String id) => '/farmer/products/$id';
  static String farmerProductStatus(String id) =>
      '/farmer/products/$id/status';

  // Admin
  static const String adminApplications = '/admin/applications';
  static String adminApplication(String id) => '/admin/applications/$id';
  static String adminApplicationAction(String id, String action) =>
      '/admin/applications/$id/$action';
  static const String adminProducts = '/admin/products';
  static String adminProduct(String id) => '/admin/products/$id';
  static String adminProductAction(String id, String action) =>
      '/admin/products/$id/$action';
  static const String adminCategories = '/admin/categories';

  // Admin - Farmers
  static const String adminFarmers = '/admin/farmers';
  static String adminFarmer(String id) => '/admin/farmers/$id';
  static String adminFarmerSuspend(String id) => '/admin/farmers/$id/suspend';
  static String adminFarmerActivate(String id) => '/admin/farmers/$id/reactivate';

  // Customer
  static const String customerFavorites = '/customer/favorites';
  static String customerFavoriteById(String id) => '/customer/favorites/$id';

  // Admin - Dashboard
  static const String adminDashboard = '/admin/dashboard';

  // Admin - Analytics
  static const String adminCityDensity = '/admin/analytics/city-density';
  static const String adminInviteNetwork = '/admin/analytics/invite-network';
}
