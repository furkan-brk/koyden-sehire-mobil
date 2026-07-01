import 'package:get/get.dart';

import 'package:koyden_sehire/models/admin/admin_product_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';

class AdminProductsController extends GetxController {
  final AdminRepository _repo;
  AdminProductsController(this._repo);

  final items = <AdminProduct>[].obs;
  final isLoading = true.obs;
  final error = ''.obs;
  final search = ''.obs;

  // Filters
  final selectedStatus = 'all'.obs; // all | pending | active | rejected | hidden
  final selectedCategoryId = ''.obs; // empty = all
  final selectedCity = ''.obs; // empty = all

  /// Unique categories present in the loaded products (MapEntry: id → name).
  List<MapEntry<String, String>> get categoryOptions {
    final map = <String, String>{};
    for (final p in items) {
      final c = p.category;
      if (c != null && c.id.isNotEmpty) map[c.id] = c.name;
    }
    final list = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  /// Unique cities present in the loaded products.
  List<String> get cityOptions {
    final set = items.map((p) => p.city).where((c) => c.isNotEmpty).toSet();
    return set.toList()..sort();
  }

  List<AdminProduct> get filteredItems {
    final q = search.value.toLowerCase();
    return items.where((p) {
      final matchesSearch = q.isEmpty ||
          p.title.toLowerCase().contains(q) ||
          (p.farmer?.displayName ?? '').toLowerCase().contains(q) ||
          (p.category?.name ?? '').toLowerCase().contains(q);
      final matchesStatus =
          selectedStatus.value == 'all' || p.status == selectedStatus.value;
      final matchesCategory = selectedCategoryId.value.isEmpty ||
          p.category?.id == selectedCategoryId.value;
      final matchesCity = selectedCity.value.isEmpty ||
          p.city.toLowerCase() == selectedCity.value.toLowerCase();
      return matchesSearch && matchesStatus && matchesCategory && matchesCity;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }


  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      items.value = await _repo.getProducts();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
