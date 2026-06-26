/// Validated invite payload returned from `GET /invites/validate`.
class InviteInfo {
  final String code;
  final String? inviterName;
  final int maxUses;
  final int usedCount;

  const InviteInfo({
    required this.code,
    this.inviterName,
    required this.maxUses,
    required this.usedCount,
  });

  int get remainingUses => maxUses - usedCount;

  factory InviteInfo.fromJson(Map<String, dynamic> json) => InviteInfo(
        code: json['code']?.toString() ?? '',
        inviterName: json['inviter_name']?.toString() ??
            (json['inviter'] as Map?)?['display_name']?.toString() ??
            (json['inviter'] as Map?)?['full_name']?.toString(),
        maxUses: (json['max_uses'] as num?)?.toInt() ?? 0,
        usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      );
}

class ApplicationFormData {
  // Step 1
  final String fullName;
  final String phone;
  final String? email;
  final String password;

  // Step 2
  final String businessName;
  final String? producerType;
  final String city;
  final String district;
  final String village;
  final String? address;
  final String bio;

  // Step 3
  final List<String> productCategorySlugs;
  final String productExamples;
  final String? productionPlaceType;
  final String? applicationNote;

  // Step 4
  final String? applicationVideoKey;

  // Step 5 (consents)
  final bool kvkkAccepted;
  final bool platformTermsAccepted;
  final bool declaresOwnProduction;
  final bool declaresAccurateLocation;
  final bool declaresNotIntermediary;

  const ApplicationFormData({
    this.fullName = '',
    this.phone = '',
    this.email,
    this.password = '',
    this.businessName = '',
    this.producerType,
    this.city = '',
    this.district = '',
    this.village = '',
    this.address,
    this.bio = '',
    this.productCategorySlugs = const [],
    this.productExamples = '',
    this.productionPlaceType,
    this.applicationNote,
    this.applicationVideoKey,
    this.kvkkAccepted = false,
    this.platformTermsAccepted = false,
    this.declaresOwnProduction = false,
    this.declaresAccurateLocation = false,
    this.declaresNotIntermediary = false,
  });

  ApplicationFormData copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? password,
    String? businessName,
    String? producerType,
    String? city,
    String? district,
    String? village,
    String? address,
    String? bio,
    List<String>? productCategorySlugs,
    String? productExamples,
    String? productionPlaceType,
    String? applicationNote,
    String? applicationVideoKey,
    bool? kvkkAccepted,
    bool? platformTermsAccepted,
    bool? declaresOwnProduction,
    bool? declaresAccurateLocation,
    bool? declaresNotIntermediary,
    bool clearVideoKey = false,
  }) =>
      ApplicationFormData(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        password: password ?? this.password,
        businessName: businessName ?? this.businessName,
        producerType: producerType ?? this.producerType,
        city: city ?? this.city,
        district: district ?? this.district,
        village: village ?? this.village,
        address: address ?? this.address,
        bio: bio ?? this.bio,
        productCategorySlugs:
            productCategorySlugs ?? this.productCategorySlugs,
        productExamples: productExamples ?? this.productExamples,
        productionPlaceType: productionPlaceType ?? this.productionPlaceType,
        applicationNote: applicationNote ?? this.applicationNote,
        applicationVideoKey: clearVideoKey
            ? null
            : (applicationVideoKey ?? this.applicationVideoKey),
        kvkkAccepted: kvkkAccepted ?? this.kvkkAccepted,
        platformTermsAccepted:
            platformTermsAccepted ?? this.platformTermsAccepted,
        declaresOwnProduction:
            declaresOwnProduction ?? this.declaresOwnProduction,
        declaresAccurateLocation:
            declaresAccurateLocation ?? this.declaresAccurateLocation,
        declaresNotIntermediary:
            declaresNotIntermediary ?? this.declaresNotIntermediary,
      );

  /// Lightweight serializer used for local draft persistence. Unlike
  /// [toJson], it does not require an invite code and includes only fields
  /// the wizard captures from the user (passwords intentionally included so
  /// the user does not have to retype them when resuming).
  Map<String, dynamic> toDraftJson() => {
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password': password,
        'business_name': businessName,
        'producer_type': producerType,
        'city': city,
        'district': district,
        'village': village,
        'address': address,
        'bio': bio,
        'product_category_slugs': productCategorySlugs,
        'product_examples': productExamples,
        'production_place_type': productionPlaceType,
        'application_note': applicationNote,
        'application_video_key': applicationVideoKey,
        'kvkk_accepted': kvkkAccepted,
        'platform_terms_accepted': platformTermsAccepted,
        'declares_own_production': declaresOwnProduction,
        'declares_accurate_location': declaresAccurateLocation,
        'declares_not_intermediary': declaresNotIntermediary,
      };

  static ApplicationFormData fromDraftJson(Map<String, dynamic> json) {
    final slugs = json['product_category_slugs'];
    return ApplicationFormData(
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      password: json['password']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      producerType: json['producer_type']?.toString(),
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      village: json['village']?.toString() ?? '',
      address: json['address']?.toString(),
      bio: json['bio']?.toString() ?? '',
      productCategorySlugs: slugs is List
          ? slugs.map((e) => e.toString()).toList()
          : const [],
      productExamples: json['product_examples']?.toString() ?? '',
      productionPlaceType: json['production_place_type']?.toString(),
      applicationNote: json['application_note']?.toString(),
      applicationVideoKey: json['application_video_key']?.toString(),
      kvkkAccepted: json['kvkk_accepted'] == true,
      platformTermsAccepted: json['platform_terms_accepted'] == true,
      declaresOwnProduction: json['declares_own_production'] == true,
      declaresAccurateLocation: json['declares_accurate_location'] == true,
      declaresNotIntermediary: json['declares_not_intermediary'] == true,
    );
  }

  Map<String, dynamic> toJson({required String inviteCode}) => {
        'invite_code': inviteCode,
        'full_name': fullName,
        'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
        'password': password,
        'business_name': businessName,
        'producer_type': producerType,
        'city': city,
        'district': district,
        'village': village,
        if (address != null && address!.isNotEmpty) 'address': address,
        'bio': bio,
        'product_categories': productCategorySlugs,
        'product_examples': productExamples,
        if (productionPlaceType != null)
          'production_place_type': productionPlaceType,
        if (applicationNote != null && applicationNote!.isNotEmpty)
          'application_note': applicationNote,
        if (applicationVideoKey != null)
          'application_video_key': applicationVideoKey,
        'kvkk_accepted': kvkkAccepted,
        'platform_terms_accepted': platformTermsAccepted,
        'declares_own_production': declaresOwnProduction,
        'declares_accurate_location': declaresAccurateLocation,
        'declares_not_intermediary': declaresNotIntermediary,
      };
}
