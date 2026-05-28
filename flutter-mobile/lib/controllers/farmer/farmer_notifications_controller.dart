import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/models/notification_model.dart';
import 'package:koyden_sehire/services/notification_repository.dart';

class FarmerNotificationsController extends GetxController {
  final NotificationRepository _repo;
  FarmerNotificationsController(this._repo);

  static const int _pageSize = 20;
  static const Duration _badgeRefreshInterval = Duration(minutes: 5);

  final RxList<AppNotification> items = <AppNotification>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxInt currentPage = 1.obs;
  final RxInt unreadCount = 0.obs;
  final RxnString errorMessage = RxnString();

  Timer? _badgePoll;

  @override
  void onInit() {
    super.onInit();
    load();
    _badgePoll = Timer.periodic(_badgeRefreshInterval, (_) => _refreshBadge());
  }

  @override
  void onClose() {
    _badgePoll?.cancel();
    super.onClose();
  }

  /// Cheap poll used to keep the bottom-nav badge fresh without churning
  /// the visible list.
  Future<void> _refreshBadge() async {
    try {
      final res = await _repo.list(role: 'farmer', page: 1, limit: 1);
      unreadCount.value = res.unreadCount;
    } catch (_) {
      // Silent.
    }
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    currentPage.value = 1;
    hasMore.value = true;
    try {
      final res = await _repo.list(
        role: 'farmer',
        page: 1,
        limit: _pageSize,
      );
      items.assignAll(res.items);
      unreadCount.value = res.unreadCount;
      hasMore.value = res.items.length >= _pageSize &&
          items.length < res.total;
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

  Future<void> loadMore() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = currentPage.value + 1;
      final res = await _repo.list(
        role: 'farmer',
        page: nextPage,
        limit: _pageSize,
      );
      if (res.items.isEmpty) {
        hasMore.value = false;
      } else {
        items.addAll(res.items);
        currentPage.value = nextPage;
        hasMore.value = res.items.length >= _pageSize &&
            items.length < res.total;
      }
    } on AppException catch (e, st) {
      debugPrint('[FarmerNotifications] loadMore failed: $e\n$st');
    } catch (e, st) {
      debugPrint('[FarmerNotifications] loadMore unexpected: $e\n$st');
    } finally {
      isLoadingMore.value = false;
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
