class CustomerProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final DateTime createdAt;

  const CustomerProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.createdAt,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) =>
      CustomerProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  CustomerProfileModel copyWith({String? fullName, String? email}) =>
      CustomerProfileModel(
        id: id,
        fullName: fullName ?? this.fullName,
        phone: phone,
        email: email ?? this.email,
        createdAt: createdAt,
      );
}
