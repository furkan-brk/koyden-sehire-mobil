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
      parse: (data) {
        final d = data as Map<String, dynamic>;
        final items = (d['items'] as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        return (
          items: items,
          total: d['total'] as int? ?? 0,
          unreadCount: d['unread_count'] as int? ?? 0,
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
