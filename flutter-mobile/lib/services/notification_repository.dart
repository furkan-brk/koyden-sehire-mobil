import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/models/notification_model.dart';

class NotificationRepository {
  final ApiClient _client;
  NotificationRepository(this._client);

  Future<({List<AppNotification> items, int total, int unreadCount})> list({
    required String role, // 'farmer' | 'customer'
    int page = 1,
    int limit = 20,
  }) async {
    final prefix = role == 'farmer' ? '/farmer' : '/customer';
    return _client.get(
      '$prefix/notifications',
      query: {'page': '$page', 'limit': '$limit'},
      parse: (raw) {
        // Backend envelope: {"success": true, "data": {items, total, unread_count}}
        // Be defensive: accept both wrapped and unwrapped shapes.
        final root = (raw as Map).cast<String, dynamic>();
        final d = (root['data'] is Map)
            ? (root['data'] as Map).cast<String, dynamic>()
            : root;
        final rawItems = (d['items'] as List?) ?? const [];
        final items = rawItems
            .map((e) => AppNotification.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ))
            .toList();
        return (
          items: items,
          total: (d['total'] as num?)?.toInt() ?? 0,
          unreadCount: (d['unread_count'] as num?)?.toInt() ?? 0,
        );
      },
    );
  }

  Future<void> markRead({required String role, required String id}) {
    final prefix = role == 'farmer' ? 'farmer' : 'customer';
    return _client.patch(
      '/$prefix/notifications/$id/read',
      parse: (_) {},
    );
  }

  Future<void> markAllRead({required String role}) {
    final prefix = role == 'farmer' ? 'farmer' : 'customer';
    return _client.patch(
      '/$prefix/notifications/read-all',
      parse: (_) {},
    );
  }
}
