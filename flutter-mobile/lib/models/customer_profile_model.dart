class CustomerProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? profileImageUrl;
  final DateTime createdAt;

  const CustomerProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.profileImageUrl,
    required this.createdAt,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) =>
      CustomerProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        profileImageUrl: json['profile_image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  CustomerProfileModel copyWith({
    String? fullName,
    String? email,
    String? profileImageUrl,
  }) =>
      CustomerProfileModel(
        id: id,
        fullName: fullName ?? this.fullName,
        phone: phone,
        email: email ?? this.email,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        createdAt: createdAt,
      );
}
