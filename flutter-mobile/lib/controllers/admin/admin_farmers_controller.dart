import 'package:get/get.dart';

import 'package:koyden_sehire/models/admin/admin_farmer_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';

class AdminFarmersController extends GetxController {
  final AdminRepository _repo;
  AdminFarmersController(this._repo);

  final isLoading = true.obs;
  final error = ''.obs;
  final _items = <AdminFarmer>[].obs;
  final search = ''.obs;
  final cityFilter = ''.obs;
  final cities = <String>[].obs;
  final selectedStatus = 'all'.obs; // all | active | suspended

  List<AdminFarmer> get filteredItems {
    final q = search.value.toLowerCase().trim();
    return _items.where((f) {
      final matchesSearch = q.isEmpty ||
          f.fullName.toLowerCase().contains(q) ||
          f.city.toLowerCase().contains(q) ||
          (f.inviteCode?.toLowerCase().contains(q) ?? false);
      final matchesStatus = selectedStatus.value == 'all' ||
          (selectedStatus.value == 'active' && f.isActive) ||
          (selectedStatus.value == 'suspended' && f.isSuspended);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
    ever(cityFilter, (_) => load());
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      final filter = cityFilter.value.isEmpty ? null : cityFilter.value;
      final result = await _repo.getFarmers(city: filter);
      _items.value = result;
      // Şehir listesini yalnızca filtresiz ilk yüklemede doldur
      if (filter == null && cities.isEmpty) {
        final unique = result.map((f) => f.city).toSet().toList()..sort();
        cities.value = unique;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
