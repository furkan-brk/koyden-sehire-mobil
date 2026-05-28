import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/services/farmer_product_repository.dart';
import 'package:koyden_sehire/models/farmer_product_model.dart';

class MyProductsController extends GetxController {
  final FarmerProductRepository _repo;
  MyProductsController(this._repo);

  /// Raw list returned by the API (unfiltered by the search field).
  final RxList<FarmerProductModel> _allItems = <FarmerProductModel>[].obs;

  /// Items after applying the in-memory search filter — what the UI binds to.
  final RxList<FarmerProductModel> items = <FarmerProductModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString statusFilter = RxnString();
  final RxString searchQuery = ''.obs;

  // ── Selection mode ──
  final RxBool selectionMode = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;
  final RxBool bulkBusy = false.obs;

  Worker? _searchWorker;

  @override
  void onInit() {
    super.onInit();
    // Debounced client-side filtering so each keystroke doesn't churn the list.
    _searchWorker = debounce<String>(
      searchQuery,
      (_) => _applyFilter(),
      time: const Duration(milliseconds: 400),
    );
    refresh();
  }

  @override
  void onClose() {
    _searchWorker?.dispose();
    super.onClose();
  }

  Future<void> setStatus(String? status) async {
    statusFilter.value = status;
    // Status changes refetch from the API; selection no longer makes sense.
    exitSelectionMode();
    await refresh();
  }

  void setSearchQuery(String q) {
    searchQuery.value = q;
  }

  void _applyFilter() {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      items.assignAll(_allItems);
      return;
    }
    items.assignAll(_allItems.where((p) {
      return p.title.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          (p.categoryName?.toLowerCase().contains(q) ?? false);
    }));
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final res = await _repo.list(status: statusFilter.value);
      _allItems.assignAll(res);
      // Drop selections that no longer exist on the server.
      selectedIds.removeWhere((id) => !res.any((p) => p.id == id));
      _applyFilter();
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> setStockStatus(String id, String stockStatus) async {
    try {
      await _repo.setStockStatus(id, stockStatus);
      await refresh();
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    }
  }

  /// Deletes a single product and refreshes the list. Returns null on
  /// success, or the localized error message on failure.
  Future<String?> deleteProduct(String id) async {
    try {
      await _repo.delete(id);
      selectedIds.remove(id);
      await refresh();
      return null;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return e.message;
    } catch (_) {
      const msg = 'Ürün silinemedi, tekrar deneyin';
      errorMessage.value = msg;
      return msg;
    }
  }

  // ── Selection mode helpers ──

  void enterSelectionMode() {
    selectionMode.value = true;
  }

  void exitSelectionMode() {
    selectionMode.value = false;
    selectedIds.clear();
  }

  void toggleSelectionMode() {
    if (selectionMode.value) {
      exitSelectionMode();
    } else {
      enterSelectionMode();
    }
  }

  void toggleSelected(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  bool isSelected(String id) => selectedIds.contains(id);

  /// Bulk-passivate every currently selected product. Returns the number of
  /// products that were successfully updated.
  Future<int> bulkPassivateSelected() async {
    if (selectedIds.isEmpty) return 0;
    bulkBusy.value = true;
    int ok = 0;
    try {
      // Snapshot ids — we mutate the underlying set as we go.
      final ids = selectedIds.toList();
      for (final id in ids) {
        try {
          await _repo.setStatus(id, 'passive');
          ok++;
        } catch (_) {
          // Continue with the rest even if one fails.
        }
      }
      await refresh();
      exitSelectionMode();
    } finally {
      bulkBusy.value = false;
    }
    return ok;
  }
}
