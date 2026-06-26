import 'package:koyden_sehire/app/constants.dart';

class FarmerProfileEdit {
  final String displayName;
  final String? producerType;
  final String city;
  final String district;
  final String village;
  final String? address;
  final String bio;
  final String publicPhone;
  final bool showPhone;
  final String? profileImageUrl;

  const FarmerProfileEdit({
    this.displayName = '',
    this.producerType,
    this.city = '',
    this.district = '',
    this.village = '',
    this.address,
    this.bio = '',
    this.publicPhone = '',
    this.showPhone = true,
    this.profileImageUrl,
  });

  factory FarmerProfileEdit.fromJson(Map<String, dynamic> json) =>
      FarmerProfileEdit(
        displayName: json['display_name']?.toString() ?? '',
        producerType: json['producer_type']?.toString(),
        city: json['city']?.toString() ?? '',
        district: json['district']?.toString() ?? '',
        village: json['village']?.toString() ?? '',
        address: json['address']?.toString(),
        bio: json['bio']?.toString() ?? '',
        publicPhone: json['public_phone']?.toString() ?? '',
        showPhone: json['show_phone'] != false,
        profileImageUrl: json['profile_image_url'] != null
            ? AppConstants.formatDevUrl(json['profile_image_url'].toString())
            : null,
      );

  FarmerProfileEdit copyWith({
    String? displayName,
    String? producerType,
    String? city,
    String? district,
    String? village,
    String? address,
    String? bio,
    String? publicPhone,
    bool? showPhone,
    String? profileImageUrl,
  }) =>
      FarmerProfileEdit(
        displayName: displayName ?? this.displayName,
        producerType: producerType ?? this.producerType,
        city: city ?? this.city,
        district: district ?? this.district,
        village: village ?? this.village,
        address: address ?? this.address,
        bio: bio ?? this.bio,
        publicPhone: publicPhone ?? this.publicPhone,
        showPhone: showPhone ?? this.showPhone,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      );

  Map<String, dynamic> toJson() => {
        'display_name': displayName.trim(),
        if (producerType != null) 'producer_type': producerType,
        'city': city.trim(),
        'district': district.trim(),
        'village': village.trim(),
        if (address != null) 'address': address!.trim(),
        'bio': bio.trim(),
        'public_phone': publicPhone.trim(),
        'show_phone': showPhone,
        if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      };
}
