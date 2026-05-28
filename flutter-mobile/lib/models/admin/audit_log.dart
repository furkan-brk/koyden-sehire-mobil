class AuditLog {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.meta,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedMeta;
    final rawMeta = json['meta'];
    if (rawMeta is Map) {
      parsedMeta = rawMeta.cast<String, dynamic>();
    }
    return AuditLog(
      id: json['id']?.toString() ?? '',
      actorId: json['actor_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      meta: parsedMeta,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}
