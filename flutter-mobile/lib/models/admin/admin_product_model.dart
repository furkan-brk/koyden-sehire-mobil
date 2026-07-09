class AdminProductFarmer {
  final String id;
  final String fullName;
  final String displayName;
  final String phone;
  final String? city;
  final String? district;
  final String status;
  final bool isVerified;
  final bool isFoundingFarmer;
  final String? profileImageUrl;

  const AdminProductFarmer({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.phone,
    this.city,
    this.district,
    required this.status,
    required this.isVerified,
    required this.isFoundingFarmer,
    this.profileImageUrl,
  });

  factory AdminProductFarmer.fromJson(Map<String, dynamic> json) {
    return AdminProductFarmer(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      status: json['status']?.toString() ?? 'active',
      isVerified: json['is_verified'] == true,
      isFoundingFarmer: json['is_founding_farmer'] == true,
      profileImageUrl: json['profile_image_url']?.toString(),
    );
  }
}

class AdminProductCategory {
  final String id;
  final String name;
  final String slug;
  final String? parentName;

  const AdminProductCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.parentName,
  });

  factory AdminProductCategory.fromJson(Map<String, dynamic> json) {
    final parent = json['parent'] as Map?;
    return AdminProductCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      parentName: parent?['name']?.toString(),
    );
  }
}

class AdminProduct {
  final String id;
  final String title;
  final String? description;
  final num price;
  final String unit;
  final String city;
  final String? district;
  final String? village;
  final String status;
  final String? stockStatus;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final List<String> imageUrls;
  final AdminProductFarmer? farmer;
  final AdminProductCategory? category;

  const AdminProduct({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.unit,
    required this.city,
    this.district,
    this.village,
    required this.status,
    this.stockStatus,
    this.rejectionReason,
    this.createdAt,
    this.publishedAt,
    this.imageUrls = const [],
    this.farmer,
    this.category,
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    final imagesRaw = json['images'] as List?;
    final images = (imagesRaw ?? [])
        .map((e) {
          if (e is String) return e;
          if (e is Map) return (e['url'] ?? e['image_url'])?.toString() ?? '';
          return '';
        })
        .where((s) => s.isNotEmpty)
        .cast<String>()
        .toList();

    final farmerJson = json['farmer'] as Map?;
    final categoryJson = json['category'] as Map?;

    return AdminProduct(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      price: (json['price'] is num)
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString(),
      village: json['village']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      stockStatus: json['stock_status']?.toString(),
      rejectionReason: json['admin_note']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      imageUrls: images,
      farmer: farmerJson != null
          ? AdminProductFarmer.fromJson(farmerJson.cast<String, dynamic>())
          : null,
      category: categoryJson != null
          ? AdminProductCategory.fromJson(
              categoryJson.cast<String, dynamic>())
          : null,
    );
  }
}
