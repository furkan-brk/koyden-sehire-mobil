import 'package:get/get.dart';

import 'package:koyden_sehire/models/admin/audit_log.dart';
import 'package:koyden_sehire/services/audit_log_repository.dart';

class AuditLogController extends GetxController {
  final AuditLogRepository _repo;
  AuditLogController(this._repo);

  static const int _pageSize = 20;

  final logs = <AuditLog>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final error = ''.obs;

  /// Selected action filter; null/empty = all actions.
  final RxnString actionFilter = RxnString();

  /// Optional actor filter (for future use; kept for repository symmetry).
  final RxnString actorIdFilter = RxnString();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Initial load / pull-to-refresh / filter change.
  Future<void> load() async {
    isLoading.value = true;
    error.value = '';
    _page = 1;
    hasMore.value = true;
    try {
      final items = await _repo.getAuditLogs(
        page: _page,
        limit: _pageSize,
        action: actionFilter.value,
        actorId: actorIdFilter.value,
      );
      logs.value = items;
      hasMore.value = items.length >= _pageSize;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || isLoading.value) return;
    isLoadingMore.value = true;
    try {
      final nextPage = _page + 1;
      final items = await _repo.getAuditLogs(
        page: nextPage,
        limit: _pageSize,
        action: actionFilter.value,
        actorId: actorIdFilter.value,
      );
      _page = nextPage;
      logs.addAll(items);
      hasMore.value = items.length >= _pageSize;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoadingMore.value = false;
    }
  }

  void setActionFilter(String? action) {
    if (actionFilter.value == action) return;
    actionFilter.value = (action == null || action.isEmpty) ? null : action;
    load();
  }
}
