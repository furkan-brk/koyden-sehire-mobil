import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/models/farmer_model.dart';

class ProductModel {
  final String id;
  final String farmerId;
  final String? categoryId;
  final String? categoryName;
  final String title;
  final String description;
  final num price;
  final String unit;
  final String city;
  final String district;
  final String? village;
  final String status; // pending|active|rejected|hidden
  final String stockStatus; // available|out_of_stock|limited
  final String? adminNote;
  final List<String> imageUrls;
  final FarmerSummary? farmer;
  final String? publicPhone;
  final DateTime? createdAt;

  const ProductModel({
    required this.id,
    required this.farmerId,
    required this.title,
    required this.description,
    required this.price,
    required this.unit,
    required this.city,
    required this.district,
    this.village,
    required this.status,
    required this.stockStatus,
    this.categoryId,
    this.categoryName,
    this.adminNote,
    this.imageUrls = const [],
    this.farmer,
    this.publicPhone,
    this.createdAt,
  });

  bool get isAvailable => stockStatus == 'available';
  bool get isOutOfStock => stockStatus == 'out_of_stock';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isHidden => status == 'hidden';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final imagesRaw = (json['images'] ?? json['image_urls']) as List?;
    final images = (imagesRaw ?? const [])
        .map((e) {
          if (e is String) return AppConstants.formatDevUrl(e);
          if (e is Map) return AppConstants.formatDevUrl((e['image_url'] ?? e['url'])?.toString() ?? '');
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList()
        .cast<String>();

    final farmerJson = json['farmer'] as Map?;
    final categoryJson = json['category'] as Map?;

    return ProductModel(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmer_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] is num)
          ? json['price'] as num
          : num.tryParse(json['price']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      village: json['village']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      stockStatus: json['stock_status']?.toString() ?? 'available',
      categoryId: json['category_id']?.toString() ??
          categoryJson?['id']?.toString(),
      categoryName: categoryJson?['name']?.toString(),
      adminNote: json['admin_note']?.toString(),
      imageUrls: images,
      farmer: farmerJson == null
          ? null
          : FarmerSummary.fromJson(farmerJson.cast<String, dynamic>()),
      publicPhone: json['public_phone']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String? get firstImage => imageUrls.isEmpty ? null : imageUrls.first;
}

class ProductFilter {
  final String? search;
  final String? categoryId;
  final String? city;
  final String? district;
  final String? sort; // price_asc | price_desc | null
  final String? stockStatus;

  const ProductFilter({
    this.search,
    this.categoryId,
    this.city,
    this.district,
    this.sort,
    this.stockStatus,
  });

  ProductFilter copyWith({
    String? search,
    String? categoryId,
    String? city,
    String? district,
    String? sort,
    String? stockStatus,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearCity = false,
    bool clearDistrict = false,
    bool clearSort = false,
  }) =>
      ProductFilter(
        search: clearSearch ? null : (search ?? this.search),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        city: clearCity ? null : (city ?? this.city),
        district: clearDistrict ? null : (district ?? this.district),
        sort: clearSort ? null : (sort ?? this.sort),
        stockStatus: stockStatus ?? this.stockStatus,
      );

  Map<String, dynamic> toQuery({required int page, required int limit}) {
    return {
      'page': page,
      'limit': limit,
      if (search?.isNotEmpty ?? false) 'search': search,
      if (categoryId?.isNotEmpty ?? false) 'category_id': categoryId,
      if (city?.isNotEmpty ?? false) 'city': city,
      if (district?.isNotEmpty ?? false) 'district': district,
      if (sort?.isNotEmpty ?? false) 'sort': sort,
      if (stockStatus?.isNotEmpty ?? false) 'stock_status': stockStatus,
    };
  }
}
