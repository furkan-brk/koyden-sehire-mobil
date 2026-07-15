import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/models/product_model.dart';
import 'package:koyden_sehire/services/favorites_repository.dart';

class FavoritesService extends GetxService {
  final FavoritesRepository _repo;
  FavoritesService(this._repo);

  final RxSet<String> ids = <String>{}.obs;
  final RxList<ProductModel> items = <ProductModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    final auth = Get.find<AuthService>();
    ever<AuthStatus>(auth.status, (status) {
      if (status == AuthStatus.customerActive) {
        refresh();
      } else if (status != AuthStatus.farmerActive) {
        clear();
      }
    });
    ever<bool>(auth.isBrowsingAsCustomer, (browsing) {
      if (browsing) {
        refresh();
      } else {
        clear();
      }
    });
  }

  bool isFavorite(String productId) => ids.contains(productId);

  Future<void> refresh() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repo.list();
      items.assignAll(list);
      ids.assignAll(list.map((p) => p.id).toSet());
    } catch (e) {
      errorMessage.value = 'Favoriler yüklenemedi';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggle(BuildContext context, String productId) async {
    final auth = Get.find<AuthService>();
    final isCustomer = auth.status.value == AuthStatus.customerActive;
    final isFarmerBrowsing = auth.status.value == AuthStatus.farmerActive &&
        auth.isBrowsingAsCustomer.value;
    if (!isCustomer && !isFarmerBrowsing) {
      Get.snackbar(
        'Giriş Gerekli',
        'Favori eklemek için giriş yapmanız gerekiyor',
        snackPosition: SnackPosition.BOTTOM,
      );
      if (context.mounted) context.go('/login');
      return;
    }

    final wasFav = ids.contains(productId);
    // Optimistic update
    if (wasFav) {
      ids.remove(productId);
      items.removeWhere((p) => p.id == productId);
    } else {
      ids.add(productId);
    }

    try {
      if (wasFav) {
        await _repo.remove(productId);
      } else {
        await _repo.add(productId);
        // Refresh to get full product data for the newly added item
        final list = await _repo.list();
        items.assignAll(list);
        ids.assignAll(list.map((p) => p.id).toSet());
      }
    } catch (_) {
      // Rollback optimistic update
      if (wasFav) {
        ids.add(productId);
        await refresh();
      } else {
        ids.remove(productId);
        items.removeWhere((p) => p.id == productId);
      }
      Get.snackbar(
        'Hata',
        'İşlem başarısız oldu, tekrar deneyin',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void clear() {
    ids.clear();
    items.clear();
    errorMessage.value = null;
  }
}
