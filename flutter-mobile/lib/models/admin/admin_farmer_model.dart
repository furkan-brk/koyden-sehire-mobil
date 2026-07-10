class AdminFarmer {
  final String id;
  final String fullName;
  final String phone;
  final String city;
  final String district;
  final String status;
  final bool isFoundingFarmer;
  final String? inviteCode;
  final int inviteQuota;
  final int usedInvites;
  final double trustScore;
  final int productCount;
  final DateTime createdAt;

  const AdminFarmer({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.district,
    required this.status,
    required this.isFoundingFarmer,
    this.inviteCode,
    required this.inviteQuota,
    required this.usedInvites,
    required this.trustScore,
    required this.productCount,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  factory AdminFarmer.fromJson(Map<String, dynamic> json) => AdminFarmer(
        id: json['id']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        district: json['district']?.toString() ?? '',
        status: json['status']?.toString() ?? 'active',
        isFoundingFarmer: json['is_founding_farmer'] == true,
        inviteCode: json['invite_code']?.toString(),
        inviteQuota: (json['invite_quota'] as num?)?.toInt() ?? 0,
        usedInvites: (json['used_invites'] as num?)?.toInt() ?? 0,
        trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0.0,
        productCount: (json['product_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class FarmerReferredBy {
  final String id;
  final String fullName;
  final String phone;
  final String city;
  final String displayName;

  const FarmerReferredBy({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.displayName,
  });

  factory FarmerReferredBy.fromJson(Map<String, dynamic> json) =>
      FarmerReferredBy(
        id: json['id']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? '',
      );
}

class FarmerReferral {
  final String id;
  final String fullName;
  final String displayName;
  final String city;
  final String status;
  final DateTime createdAt;
  final String? inviteCode;

  const FarmerReferral({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.city,
    required this.status,
    required this.createdAt,
    this.inviteCode,
  });

  bool get isActive => status == 'active';

  factory FarmerReferral.fromJson(Map<String, dynamic> json) => FarmerReferral(
        id: json['id']?.toString() ?? '',
        fullName: json['full_name']?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        status: json['status']?.toString() ?? 'active',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        inviteCode: json['invite_code']?.toString(),
      );
}

class AdminFarmerProductBrief {
  final String id;
  final String title;
  final double price;
  final String unit;
  final String status;
  final String categoryName;
  final String imageUrl;

  const AdminFarmerProductBrief({
    required this.id,
    required this.title,
    required this.price,
    required this.unit,
    required this.status,
    required this.categoryName,
    required this.imageUrl,
  });

  factory AdminFarmerProductBrief.fromJson(Map<String, dynamic> json) =>
      AdminFarmerProductBrief(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        categoryName: json['category_name']?.toString() ?? '',
        imageUrl: json['image_url']?.toString() ?? '',
      );
}

class AdminFarmerDetail extends AdminFarmer {
  final double profileCompletion;
  final bool hasVideoVerification;
  final int approvedProducts;
  final int complaints;
  final int inviteHistory;
  final FarmerReferredBy? referredBy;
  final List<FarmerReferral> referrals;
  final List<AdminFarmerProductBrief> products;

  const AdminFarmerDetail({
    required super.id,
    required super.fullName,
    required super.phone,
    required super.city,
    required super.district,
    required super.status,
    required super.isFoundingFarmer,
    super.inviteCode,
    required super.inviteQuota,
    required super.usedInvites,
    required super.trustScore,
    required super.productCount,
    required super.createdAt,
    required this.profileCompletion,
    required this.hasVideoVerification,
    required this.approvedProducts,
    required this.complaints,
    required this.inviteHistory,
    this.referredBy,
    this.referrals = const [],
    this.products = const [],
  });

  factory AdminFarmerDetail.fromJson(Map<String, dynamic> json) {
    final base = AdminFarmer.fromJson(json);
    return AdminFarmerDetail(
      id: base.id,
      fullName: base.fullName,
      phone: base.phone,
      city: base.city,
      district: base.district,
      status: base.status,
      isFoundingFarmer: base.isFoundingFarmer,
      inviteCode: base.inviteCode,
      inviteQuota: base.inviteQuota,
      usedInvites: base.usedInvites,
      trustScore: base.trustScore,
      productCount: base.productCount,
      createdAt: base.createdAt,
      profileCompletion:
          (json['profile_completion'] as num?)?.toDouble() ?? 0.0,
      hasVideoVerification: json['has_video_verification'] == true,
      approvedProducts: (json['approved_products'] as num?)?.toInt() ?? 0,
      complaints: (json['complaints'] as num?)?.toInt() ?? 0,
      inviteHistory: (json['invite_history'] as num?)?.toInt() ?? 0,
      referredBy: json['referred_by'] == null
          ? null
          : FarmerReferredBy.fromJson(
              (json['referred_by'] as Map).cast<String, dynamic>()),
      referrals: (json['referrals'] as List?)
              ?.map((e) => FarmerReferral.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      products: (json['products'] as List?)
              ?.map((e) => AdminFarmerProductBrief.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }
}
