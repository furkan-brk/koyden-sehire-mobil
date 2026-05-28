class AdminCategory {
  final String id;
  final String name;
  final String? parentId;
  final bool active;
  final int sortOrder;
  final List<AdminCategory> children;

  const AdminCategory({
    required this.id,
    required this.name,
    this.parentId,
    required this.active,
    required this.sortOrder,
    this.children = const [],
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    final childrenRaw = json['children'] as List?;
    return AdminCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      active: json['is_active'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      children: (childrenRaw ?? [])
          .map((e) =>
              AdminCategory.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
