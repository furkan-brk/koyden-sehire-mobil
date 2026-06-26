import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'package:koyden_sehire/app/constants.dart';

class GeocodedAddress {
  final String city;
  final String district;
  final String village;
  final String streetAddress;
  final String formattedAddress;

  const GeocodedAddress({
    this.city = '',
    this.district = '',
    this.village = '',
    this.streetAddress = '',
    this.formattedAddress = '',
  });
}

class GoogleGeocodingService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  final Dio _dio;

  GoogleGeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  Future<GeocodedAddress?> reverseGeocode(double lat, double lng) async {
    const apiKey = AppConstants.googleMapsApiKey;
    if (apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': apiKey,
          'language': 'tr',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      if (data == null) return null;

      final status = data['status'] as String?;
      if (status != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      // Tüm result'ların component'larını tarayarak en dolu il/ilçe/mahalle bilgisini topla
      String city = '';
      String district = '';
      String locality = '';
      String sublocality = '';
      String route = '';
      String streetNumber = '';
      String topFormattedAddress = '';

      for (int i = 0; i < results.length; i++) {
        final result = results[i] as Map<String, dynamic>;
        final components = result['address_components'] as List<dynamic>? ?? [];

        if (i == 0) {
          topFormattedAddress = result['formatted_address'] as String? ?? '';
        }

        for (final comp in components) {
          final c = comp as Map<String, dynamic>;
          final name = c['long_name'] as String? ?? '';
          final types = (c['types'] as List<dynamic>?)?.cast<String>() ?? [];

          if (city.isEmpty && types.contains('administrative_area_level_1')) city = name;
          if (district.isEmpty && types.contains('administrative_area_level_2')) district = name;
          if (locality.isEmpty && types.contains('locality')) locality = name;
          if (sublocality.isEmpty && types.contains('sublocality_level_1')) sublocality = name;
          if (route.isEmpty && types.contains('route')) route = name;
          if (streetNumber.isEmpty && types.contains('street_number')) streetNumber = name;
        }

        // İl + İlçe bilgisi toplandıysa daha fazla aramaya gerek yok
        if (city.isNotEmpty && district.isNotEmpty) break;
      }

      // Google Türkiye'de bazen "X İl" / "X İlçesi" şeklinde döndürür — temizle
      city = city
          .replaceFirst(RegExp(r'\s+İl$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^İl\s+', caseSensitive: false), '');
      district = district
          .replaceFirst(RegExp(r'\s+İlçe(si)?$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^İlçe\s+', caseSensitive: false), '');

      final village = sublocality.isNotEmpty ? sublocality : locality;

      final streetParts = [
        if (route.isNotEmpty) route,
        if (streetNumber.isNotEmpty) streetNumber,
      ];
      final streetAddress = streetParts.join(' No:');

      return GeocodedAddress(
        city: city,
        district: district,
        village: village,
        streetAddress: streetAddress,
        formattedAddress: topFormattedAddress,
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> searchAddress(String searchQuery) async {
    const apiKey = AppConstants.googleMapsApiKey;
    if (apiKey.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/place/textsearch/json',
        queryParameters: {
          'query': searchQuery,
          'key': apiKey,
          'language': 'tr',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      if (data == null) return null;

      final status = data['status'] as String?;
      if (status != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final geometry = results.first['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final location = geometry['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();

      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }
}
