import 'package:get/get.dart';

import 'package:koyden_sehire/services/farmer_repository.dart';
import 'package:koyden_sehire/models/farmer_model.dart';

class ProducersListController extends GetxController {
  final FarmerRepository _repo;
  ProducersListController(this._repo);

  final RxList<FarmerSummary> items = <FarmerSummary>[].obs;
  final RxInt page = 1.obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxInt total = 0.obs;
  final RxnString errorMessage = RxnString();
  final RxnString city = RxnString();
  final RxnString district = RxnString();
  final RxnString search = RxnString();

  @override
  void onInit() {
    super.onInit();
    _load(reset: true);
  }

  Future<void> applySearch(String? q) async {
    search.value = (q?.trim().isEmpty ?? true) ? null : q?.trim();
    await _load(reset: true);
  }

  Future<void> applyLocation({String? c, String? d}) async {
    city.value = (c?.trim().isEmpty ?? true) ? null : c?.trim();
    district.value = (d?.trim().isEmpty ?? true) ? null : d?.trim();
    await _load(reset: true);
  }

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = page.value + 1;
      final res = await _repo.list(
        page: nextPage,
        city: city.value,
        district: district.value,
        search: search.value,
      );
      items.addAll(res.items);
      page.value = res.pagination.page;
      hasMore.value = res.pagination.hasMore;
      total.value = res.pagination.total;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> _load({required bool reset}) async {
    isLoading.value = true;
    errorMessage.value = null;
    if (reset) {
      items.clear();
      page.value = 1;
    }
    try {
      final res = await _repo.list(
        page: 1,
        city: city.value,
        district: district.value,
        search: search.value,
      );
      items.assignAll(res.items);
      page.value = res.pagination.page;
      hasMore.value = res.pagination.hasMore;
      total.value = res.pagination.total;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
