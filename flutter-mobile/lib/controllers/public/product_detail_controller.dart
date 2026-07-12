import 'package:get/get.dart';

import 'package:koyden_sehire/services/farmer_repository.dart';
import 'package:koyden_sehire/services/product_repository.dart';
import 'package:koyden_sehire/models/product_model.dart';

class ProductDetailController extends GetxController {
  final ProductRepository _repo;
  final FarmerRepository _farmerRepo;
  final String productId;
  ProductDetailController(
    this._repo,
    this._farmerRepo, {
    required this.productId,
  });

  final RxBool isLoading = false.obs;
  final Rxn<ProductModel> product = Rxn<ProductModel>();
  final RxnString error = RxnString();

  final RxList<ProductModel> relatedProducts = <ProductModel>[].obs;
  final RxBool isLoadingRelated = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      product.value = await _repo.getById(productId);
      _loadRelated();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads the farmer's other active products for the "Üreticinin Diğer
  /// Ürünleri" carousel. Failures are swallowed — the section simply hides.
  Future<void> _loadRelated() async {
    final farmer = product.value?.farmer;
    if (farmer == null) return;
    isLoadingRelated.value = true;
    try {
      final result =
          await _farmerRepo.getProducts(farmer.id, page: 1, limit: 11);
      relatedProducts.assignAll(
        result.items.where((p) => p.id != productId).take(10),
      );
    } catch (_) {
      relatedProducts.clear();
    } finally {
      isLoadingRelated.value = false;
    }
  }
}
