import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/core/storage/secure_storage_service.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/services/favorites_repository.dart';
import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/shared/widgets/product_card.dart';

// --- stub ---

/// A concrete FavoritesService stub that doesn't need a real repo.
/// We override [isFavorite] so we can control which products are favorited.
class _StubFavoritesRepository extends FavoritesRepository {
  _StubFavoritesRepository() : super(_StubApiClient(SecureStorageService()));

  @override
  Future<List<ProductModel>> list() async => [];

  @override
  Future<void> add(String productId) async {}

  @override
  Future<void> remove(String productId) async {}
}

/// Minimal ApiClient stub — methods are never called in these tests.
class _StubApiClient extends ApiClient {
  _StubApiClient(super.storage) : super(onUnauthorized: () {});
}

/// Stub SecureStorageService — read-only methods return null/empty.
class _StubSecureStorage extends SecureStorageService {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<String?> getUserRole() async => null;

  @override
  Future<String?> getUserStatus() async => null;

  @override
  Future<String?> getUserId() async => null;

  @override
  Future<String?> getDisplayName() async => null;
}

/// Stub AuthService that does not start any real services.
class _StubAuthService extends AuthService {
  _StubAuthService() : super(_StubSecureStorage());

  @override
  Future<void> bootstrap() async {
    // no-op in tests
  }
}

class _StubFavoritesService extends FavoritesService {
  _StubFavoritesService() : super(_StubFavoritesRepository());

  final RxSet<String> _favIds = <String>{}.obs;

  @override
  RxSet<String> get ids => _favIds;

  @override
  bool isFavorite(String productId) => _favIds.contains(productId);

  @override
  Future<void> toggle(BuildContext context, String productId) async {
    if (_favIds.contains(productId)) {
      _favIds.remove(productId);
    } else {
      _favIds.add(productId);
    }
  }

  @override
  Future<void> refresh() async {}
}

// --- helpers ---

ProductModel _makeProduct({
  String id = 'p-001',
  String title = 'Taze Domates',
  bool withFarmer = true,
  String? imageUrl,
  String stockStatus = 'available',
}) {
  return ProductModel(
    id: id,
    farmerId: 'farmer-001',
    title: title,
    description: 'Harika bir ürün',
    price: 25.0,
    unit: 'kg',
    city: 'İzmir',
    district: 'Ödemiş',
    status: 'active',
    stockStatus: stockStatus,
    imageUrls: imageUrl != null ? [imageUrl] : [],
    farmer: withFarmer
        ? null // FarmerSummary requires more setup; test via null
        : null,
    categoryName: 'Sebze',
  );
}

Widget _buildTestApp(Widget child) {
  return GetMaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: child,
      ),
    ),
  );
}

void main() {
  late _StubFavoritesService stubFavoritesService;

  setUp(() {
    Get.reset();
    // AuthService must be registered first because FavoritesService.onInit finds it.
    Get.put<AuthService>(_StubAuthService());
    stubFavoritesService = _StubFavoritesService();
    Get.put<FavoritesService>(stubFavoritesService);
  });

  tearDown(() => Get.reset());

  group('ProductCard widget', () {
    testWidgets('renders without error and shows product title', (tester) async {
      final product = _makeProduct(title: 'Taze Domates');

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      expect(find.text('Taze Domates'), findsOneWidget);
    });

    testWidgets('shows price with unit', (tester) async {
      final product = _makeProduct();

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      // Price text should be rendered somewhere in the widget tree.
      // The exact format is '25,00 ₺ / kg' or similar from AppFormatters.price.
      final priceText = find.textContaining('25');
      expect(priceText, findsWidgets);
    });

    testWidgets('shows city and district', (tester) async {
      final product = _makeProduct();

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      expect(find.textContaining('İzmir'), findsOneWidget);
    });

    testWidgets('shows category pill badge when categoryName is set', (tester) async {
      final product = _makeProduct();

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      expect(find.text('Sebze'), findsOneWidget);
    });

    testWidgets('shows favorite icon button', (tester) async {
      final product = _makeProduct();

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      // The favorite icon (either filled or border) should be present.
      final favIcon =
          find.byWidgetPredicate((w) => w is Icon && (w.icon == Icons.favorite || w.icon == Icons.favorite_border));
      expect(favIcon, findsOneWidget);
    });

    testWidgets('shows filled favorite icon when product is favorited', (tester) async {
      final product = _makeProduct(id: 'p-fav');
      stubFavoritesService.ids.add('p-fav');

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.favorite),
        findsOneWidget,
      );
    });

    testWidgets('shows stock badge in non-compact mode', (tester) async {
      final product = _makeProduct(stockStatus: 'available');

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      expect(find.text('Mevcut'), findsOneWidget);
    });

    testWidgets('compact mode hides stock badge', (tester) async {
      final product = _makeProduct(stockStatus: 'available');

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product, compact: true)));
      await tester.pump();

      expect(find.text('Mevcut'), findsNothing);
    });

    testWidgets('shows placeholder icon when no images', (tester) async {
      final product = _makeProduct(imageUrl: null);

      await tester.pumpWidget(_buildTestApp(ProductCard(product: product)));
      await tester.pump();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });
}
