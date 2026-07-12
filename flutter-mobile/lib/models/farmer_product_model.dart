import 'package:koyden_sehire/app/constants.dart';

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
  final int favoriteCount;
  final int viewCount;

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
    this.favoriteCount = 0,
    this.viewCount = 0,
  });

  factory FarmerProductModel.fromJson(Map<String, dynamic> json) {
    final imagesRaw = (json['images'] ?? json['image_urls']) as List?;
    var images = (imagesRaw ?? const [])
        .map((e) {
          if (e is String) return AppConstants.formatDevUrl(e);
          if (e is Map) return AppConstants.formatDevUrl((e['image_url'] ?? e['url'])?.toString() ?? '');
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList()
        .cast<String>();
    // Fallback for endpoints that return a single `image_url` string (e.g.
    // farmer dashboard's recent products).
    if (images.isEmpty) {
      final single = json['image_url']?.toString();
      if (single != null && single.isNotEmpty) {
        images = [AppConstants.formatDevUrl(single)];
      }
    }
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
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
    );
  }
}

