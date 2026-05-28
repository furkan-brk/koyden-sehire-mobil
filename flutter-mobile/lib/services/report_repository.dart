import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';

class ReportRepository {
  final ApiClient _client;
  ReportRepository(this._client);

  /// Submits an inappropriate content / abuse report.
  /// [targetType] e.g. 'product' | 'farmer'.
  /// [targetId] is the UUID of the entity being reported.
  /// [reason] is a short reason key (e.g. 'inappropriate', 'misleading',
  /// 'spam', 'other').
  /// [note] is optional free-form text (used when reason == 'other').
  Future<void> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String note = '',
  }) async {
    await _client.post(
      ApiEndpoints.reports,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'note': note,
      },
      parse: (_) => null,
    );
  }
}
