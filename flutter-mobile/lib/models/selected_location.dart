class SelectedLocation {
  final String city;
  final String district;
  final String village;
  final String formattedAddress;
  final double lat;
  final double lng;

  const SelectedLocation({
    required this.city,
    required this.district,
    required this.village,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}
