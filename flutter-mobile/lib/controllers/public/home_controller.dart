import 'package:get/get.dart';

import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/services/farmer_repository.dart';
import 'package:koyden_sehire/services/product_repository.dart';
import 'package:koyden_sehire/models/product_model.dart';

class HomeController extends GetxController {
  final ProductRepository _productRepo;
  final FarmerRepository _farmerRepo;
  HomeController(this._productRepo, this._farmerRepo);

  final RxBool isLoading = false.obs;
  final RxList<ProductModel> newProducts = <ProductModel>[].obs;
  final RxList<FarmerSummary> featuredFarmers = <FarmerSummary>[].obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      await Future.wait([_loadProducts(), _loadFarmers()]);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProducts() async {
    final res = await _productRepo.list(
      filter: const ProductFilter(),
      page: 1,
      limit: 10,
    );
    newProducts.assignAll(res.items);
  }

  Future<void> _loadFarmers() async {
    final res = await _farmerRepo.list(limit: 8);
    featuredFarmers.assignAll(res.items);
  }
}
