class AdminApplication {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String businessName;
  final String producerType;
  final String city;
  final String district;
  final String? village;
  final String? bio;
  final List<String> productCategories;
  final String? productExamples;
  final String? productionPlaceType;
  final List<String> documentUrls;
  final String? applicationNote;
  final String? applicationVideoUrl;
  final bool kvkkAccepted;
  final bool platformTermsAccepted;
  final bool declaresOwnProduction;
  final bool declaresAccurateLocation;
  final bool declaresNotIntermediary;
  final String status;
  final String? rejectionReason;
  final String? adminNote;
  final DateTime createdAt;
  final String? inviteCode;
  // Legacy / risk fields kept for list view compatibility
  final String? inviteTrust;
  final String? riskLevel;

  const AdminApplication({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.businessName,
    required this.producerType,
    required this.city,
    required this.district,
    this.village,
    this.bio,
    required this.productCategories,
    this.productExamples,
    this.productionPlaceType,
    required this.documentUrls,
    this.applicationNote,
    this.applicationVideoUrl,
    required this.kvkkAccepted,
    required this.platformTermsAccepted,
    required this.declaresOwnProduction,
    required this.declaresAccurateLocation,
    required this.declaresNotIntermediary,
    required this.status,
    this.rejectionReason,
    this.adminNote,
    required this.createdAt,
    this.inviteCode,
    this.inviteTrust,
    this.riskLevel,
  });

  factory AdminApplication.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return AdminApplication(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      businessName: json['business_name']?.toString() ?? '',
      producerType: json['producer_type']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      village: json['village']?.toString(),
      bio: json['bio']?.toString(),
      productCategories: parseStringList(json['product_categories']),
      productExamples: json['product_examples']?.toString(),
      productionPlaceType: json['production_place_type']?.toString(),
      documentUrls: parseStringList(json['document_urls']),
      applicationNote: json['application_note']?.toString(),
      applicationVideoUrl: json['application_video_url']?.toString(),
      kvkkAccepted: json['kvkk_accepted'] == true,
      platformTermsAccepted: json['platform_terms_accepted'] == true,
      declaresOwnProduction: json['declares_own_production'] == true,
      declaresAccurateLocation: json['declares_accurate_location'] == true,
      declaresNotIntermediary: json['declares_not_intermediary'] == true,
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      adminNote: json['admin_note']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      inviteCode: json['invite_code']?.toString(),
      inviteTrust: json['invite_trust']?.toString(),
      riskLevel: json['risk_level']?.toString(),
    );
  }
}
