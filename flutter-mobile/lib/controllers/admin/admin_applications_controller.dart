import 'package:get/get.dart';

import 'package:koyden_sehire/models/admin/admin_application_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';

class AdminApplicationsController extends GetxController {
  final AdminRepository _repo;
  AdminApplicationsController(this._repo);

  final items = <AdminApplication>[].obs;
  final isLoading = true.obs;
  final error = ''.obs;
  final search = ''.obs;

  // Filters — "all" by default so needs_video/approved/rejected rows are visible.
  final selectedStatus =
      'all'.obs; // all | pending | needs_video | approved | rejected
  final selectedCity = ''.obs; // empty = all

  /// Unique cities present in the loaded applications.
  List<String> get cityOptions {
    final set = items.map((a) => a.city).where((c) => c.isNotEmpty).toSet();
    return set.toList()..sort();
  }

  List<AdminApplication> get filteredItems {
    final q = search.value.toLowerCase();
    return items.where((a) {
      final matchesSearch = q.isEmpty ||
          a.fullName.toLowerCase().contains(q) ||
          a.city.toLowerCase().contains(q) ||
          (a.inviteCode ?? '').toLowerCase().contains(q);
      final matchesStatus =
          selectedStatus.value == 'all' || a.status == selectedStatus.value;
      final matchesCity = selectedCity.value.isEmpty ||
          a.city.toLowerCase() == selectedCity.value.toLowerCase();
      return matchesSearch && matchesStatus && matchesCity;
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
      items.value = await _repo.getApplications();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
