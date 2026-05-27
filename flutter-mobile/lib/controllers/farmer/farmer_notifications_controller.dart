import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/models/notification_model.dart';
import 'package:koyden_sehire/services/notification_repository.dart';

class FarmerNotificationsController extends GetxController {
  final NotificationRepository _repo;
  FarmerNotificationsController(this._repo);

  final RxList<AppNotification> items = <AppNotification>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt unreadCount = 0.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final res = await _repo.list(role: 'farmer');
      items.assignAll(res.items);
      unreadCount.value = res.unreadCount;
    } on AppException catch (e, st) {
      debugPrint('[FarmerNotifications] load failed: $e\n$st');
      errorMessage.value = e.message;
    } catch (e, st) {
      debugPrint('[FarmerNotifications] load unexpected: $e\n$st');
      errorMessage.value = 'Bildirimler yüklenemedi. Lütfen tekrar deneyin.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(role: 'farmer', id: id);
      final idx = items.indexWhere((n) => n.id == id);
      if (idx != -1 && !items[idx].isRead) {
        items[idx] = items[idx].copyWith(isRead: true);
        if (unreadCount.value > 0) unreadCount.value--;
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead(role: 'farmer');
      items.assignAll(items.map((n) => n.copyWith(isRead: true)).toList());
      unreadCount.value = 0;
    } catch (_) {}
  }
}
