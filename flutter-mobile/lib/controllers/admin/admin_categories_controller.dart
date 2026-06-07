import 'package:get/get.dart';

import 'package:koyden_sehire/models/admin/admin_category_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';

class AdminCategoriesController extends GetxController {
  final AdminRepository _repo;
  AdminCategoriesController(this._repo);

  final items = <AdminCategory>[].obs;
  final isLoading = true.obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    try {
      items.value = await _repo.getCategories();
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addSubcategory(String parentId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _repo.createSubcategory(
        parentId: parentId,
        name: trimmed,
        slug: _toSlug(trimmed),
      );
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSubcategory(String id) async {
    try {
      await _repo.deleteCategory(id);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _toSlug(String input) {
    const trMap = {
      'ç': 'c', 'Ç': 'c',
      'ş': 's', 'Ş': 's',
      'ğ': 'g', 'Ğ': 'g',
      'ı': 'i', 'İ': 'i',
      'ö': 'o', 'Ö': 'o',
      'ü': 'u', 'Ü': 'u',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(trMap[ch] ?? ch);
    }
    return buffer.toString()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
