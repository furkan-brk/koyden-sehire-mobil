import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/models/admin/audit_log.dart';

class AuditLogRepository {
  final ApiClient _client;
  AuditLogRepository(this._client);

  static const String _endpoint = '/admin/audit-logs';

  Future<List<AuditLog>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? actorId,
  }) async {
    return _client.get<List<AuditLog>>(
      _endpoint,
      query: {
        'page': page,
        'limit': limit,
        if (action != null && action.isNotEmpty) 'action': action,
        if (actorId != null && actorId.isNotEmpty) 'actor_id': actorId,
      },
      parse: (d) {
        final list = (d['data'] ?? d) as List?;
        return (list ?? [])
            .map((e) => AuditLog.fromJson(
                (e as Map).cast<String, dynamic>()))
            .toList();
      },
    );
  }
}
