import 'package:get/get.dart';

import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/services/farmer_repository.dart';
import 'package:koyden_sehire/models/farmer_model.dart';

class FarmerController extends GetxController {
  final FarmerRepository _repo;
  final String farmerId;
  FarmerController(this._repo, {required this.farmerId});

  static const _pageSize = 20;

  final RxBool isLoadingProfile = false.obs;
  final Rxn<FarmerProfile> profile = Rxn<FarmerProfile>();
  final RxnString profileError = RxnString();

  final RxBool isLoadingProducts = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxnString productsError = RxnString();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    load();
    loadProducts();
  }

  Future<void> load() async {
    isLoadingProfile.value = true;
    profileError.value = null;
    try {
      profile.value = await _repo.getById(farmerId);
    } catch (e) {
      profileError.value = e.toString();
    } finally {
      isLoadingProfile.value = false;
    }
  }

  Future<void> loadProducts() async {
    isLoadingProducts.value = true;
    productsError.value = null;
    _page = 1;
    try {
      final result =
          await _repo.getProducts(farmerId, page: _page, limit: _pageSize);
      products.assignAll(result.items);
      hasMore.value = _page < result.pagination.totalPages;
    } catch (e) {
      productsError.value = e.toString();
    } finally {
      isLoadingProducts.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || isLoadingProducts.value || !hasMore.value) {
      return;
    }
    isLoadingMore.value = true;
    try {
      final next = _page + 1;
      final result =
          await _repo.getProducts(farmerId, page: next, limit: _pageSize);
      _page = next;
      products.addAll(result.items);
      hasMore.value = _page < result.pagination.totalPages;
    } catch (_) {
      // Sessizce yut — kullanıcı tekrar kaydırınca yeniden denenir.
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([load(), loadProducts()]);
  }
}
