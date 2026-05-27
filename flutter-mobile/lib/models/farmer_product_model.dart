class FarmerProductModel {
  final String id;
  final String title;
  final String description;
  final num price;
  final String unit;
  final String city;
  final String district;
  final String village;
  final String? categoryId;
  final String? categoryName;
  final String status;
  final String stockStatus;
  final String? adminNote;
  final List<String> imageUrls;
  final DateTime? createdAt;

  const FarmerProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.unit,
    required this.city,
    required this.district,
    required this.village,
    this.categoryId,
    this.categoryName,
    required this.status,
    required this.stockStatus,
    this.adminNote,
    this.imageUrls = const [],
    this.createdAt,
  });

  factory FarmerProductModel.fromJson(Map<String, dynamic> json) {
    final imagesRaw = (json['images'] ?? json['image_urls']) as List?;
    final images = (imagesRaw ?? const [])
        .map((e) {
          if (e is String) return e;
          if (e is Map) return (e['image_url'] ?? e['url'])?.toString() ?? '';
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList()
        .cast<String>();
    final cat = json['category'] as Map?;
    return FarmerProductModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] is num)
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      village: json['village']?.toString() ?? '',
      categoryId:
          json['category_id']?.toString() ?? cat?['id']?.toString(),
      categoryName: cat?['name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      stockStatus: json['stock_status']?.toString() ?? 'available',
      adminNote: json['admin_note']?.toString(),
      imageUrls: images,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

