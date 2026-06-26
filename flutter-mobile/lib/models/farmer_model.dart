import 'package:koyden_sehire/app/constants.dart';

/// Compact representation embedded in a product response.
class FarmerSummary {
  final String id;
  final String displayName;
  final String? profileImageUrl;
  final String city;
  final String district;
  final String? village;
  final String? producerType;
  final bool isVerified;
  final bool isFoundingFarmer;

  const FarmerSummary({
    required this.id,
    required this.displayName,
    this.profileImageUrl,
    required this.city,
    required this.district,
    this.village,
    this.producerType,
    this.isVerified = false,
    this.isFoundingFarmer = false,
  });

  factory FarmerSummary.fromJson(Map<String, dynamic> json) => FarmerSummary(
        id: (json['id'] ?? json['user_id'])?.toString() ?? '',
        displayName: json['display_name']?.toString() ??
            json['full_name']?.toString() ??
            '',
        profileImageUrl: json['profile_image_url'] != null
            ? AppConstants.formatDevUrl(json['profile_image_url'].toString())
            : null,
        city: json['city']?.toString() ?? '',
        district: json['district']?.toString() ?? '',
        village: json['village']?.toString(),
        producerType: json['producer_type']?.toString(),
        isVerified: json['is_verified'] == true,
        isFoundingFarmer: json['is_founding_farmer'] == true,
      );
}

class FarmerProfile {
  final String id;
  final String displayName;
  final String? profileImageUrl;
  final String city;
  final String district;
  final String? village;
  final String? address;
  final String? producerType;
  final String? bio;
  final String? publicPhone;
  final bool showPhone;
  final bool isVerified;
  final bool isFoundingFarmer;

  const FarmerProfile({
    required this.id,
    required this.displayName,
    this.profileImageUrl,
    required this.city,
    required this.district,
    this.village,
    this.address,
    this.producerType,
    this.bio,
    this.publicPhone,
    this.showPhone = true,
    this.isVerified = false,
    this.isFoundingFarmer = false,
  });

  factory FarmerProfile.fromJson(Map<String, dynamic> json) => FarmerProfile(
        id: (json['id'] ?? json['user_id'])?.toString() ?? '',
        displayName: json['display_name']?.toString() ?? '',
        profileImageUrl: json['profile_image_url'] != null
            ? AppConstants.formatDevUrl(json['profile_image_url'].toString())
            : null,
        city: json['city']?.toString() ?? '',
        district: json['district']?.toString() ?? '',
        village: json['village']?.toString(),
        address: json['address']?.toString(),
        producerType: json['producer_type']?.toString(),
        bio: json['bio']?.toString(),
        publicPhone: json['public_phone']?.toString(),
        showPhone: json['show_phone'] != false,
        isVerified: json['is_verified'] == true,
        isFoundingFarmer: json['is_founding_farmer'] == true,
      );
}

const Map<String, String> producerTypeLabels = {
  'individual_farmer': 'Bireysel Çiftçi',
  'family_producer': 'Aile Üreticisi',
  'cooperative': 'Kooperatif',
  'small_producer': 'Küçük Üretici',
  'dairy_producer': 'Süt Üreticisi',
  'beekeeper': 'Arıcı',
  'olive_producer': 'Zeytin/Zeytinyağı Üreticisi',
  'other': 'Diğer',
};

String producerTypeLabel(String? key) =>
    producerTypeLabels[key ?? ''] ?? 'Üretici';

const Map<String, String> productionPlaceLabels = {
  'own_land': 'Kendi Arazisi',
  'family_land': 'Aile Arazisi',
  'rented_land': 'Kiralık Arazi',
  'cooperative_production': 'Kooperatif Üretimi',
  'home_production': 'Ev Üretimi',
  'other': 'Diğer',
};
