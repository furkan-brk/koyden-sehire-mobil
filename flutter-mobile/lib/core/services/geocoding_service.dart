import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

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

/// Nominatim (OpenStreetMap) tabanlı geokodlama — API anahtarı gerektirmez.
/// Adil kullanım: en fazla 1 istek/sn ve tanımlayıcı User-Agent zorunlu.
class GeocodingService {
  static const String _reverseUrl = 'https://nominatim.openstreetmap.org/reverse';
  static const String _searchUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'KoydenSehire/1.0 (koydensehire.com)';

  final Dio _dio;

  GeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  Options get _options => Options(
        headers: {'User-Agent': _userAgent},
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      );

  /// Türkiye OSM hiyerarşisinde il `province` (nadiren `state`/`city`),
  /// ilçe `town` (büyükşehir dahil; nadiren `county`/`district`) olarak gelir.
  Future<GeocodedAddress?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _reverseUrl,
        queryParameters: {
          'format': 'jsonv2',
          'lat': '$lat',
          'lon': '$lng',
          'accept-language': 'tr',
          'addressdetails': '1',
          'zoom': '16',
        },
        options: _options,
      );

      final data = response.data;
      if (data == null || data['error'] != null) {
        debugPrint('[geocoding] reverse failed: ${data?['error'] ?? 'empty response'}');
        return null;
      }

      final address = data['address'] as Map<String, dynamic>? ?? {};
      String pick(List<String> keys) {
        for (final k in keys) {
          final v = address[k] as String? ?? '';
          if (v.isNotEmpty) return v;
        }
        return '';
      }

      String city = pick(['province', 'state', 'city']);
      String district = pick(['town', 'county', 'district', 'city_district']);
      final village = pick(['village', 'suburb', 'neighbourhood', 'hamlet']);
      final road = pick(['road']);
      final houseNumber = pick(['house_number']);

      // Nadiren "X İli" / "X İlçesi" biçiminde gelebilir — temizle
      city = city
          .replaceFirst(RegExp(r'\s+İl(i)?$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^İl\s+', caseSensitive: false), '');
      district = district
          .replaceFirst(RegExp(r'\s+İlçe(si)?$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^İlçe\s+', caseSensitive: false), '');

      final streetParts = [
        if (road.isNotEmpty) road,
        if (houseNumber.isNotEmpty) houseNumber,
      ];

      return GeocodedAddress(
        city: city,
        district: district,
        village: village,
        streetAddress: streetParts.join(' No:'),
        formattedAddress: data['display_name'] as String? ?? '',
      );
    } on DioException catch (e) {
      debugPrint('[geocoding] reverse DioException: ${e.type} ${e.response?.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[geocoding] reverse parse error: $e');
      return null;
    }
  }

  Future<LatLng?> searchAddress(String searchQuery) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        _searchUrl,
        queryParameters: {
          'q': searchQuery,
          'format': 'jsonv2',
          'limit': '1',
          'accept-language': 'tr',
          'countrycodes': 'tr',
        },
        options: _options,
      );

      final results = response.data;
      if (results == null || results.isEmpty) {
        debugPrint('[geocoding] search: no results for "$searchQuery"');
        return null;
      }

      final first = results.first as Map<String, dynamic>;
      final lat = double.parse(first['lat'] as String);
      final lng = double.parse(first['lon'] as String);
      return LatLng(lat, lng);
    } on DioException catch (e) {
      debugPrint('[geocoding] search DioException: ${e.type} ${e.response?.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[geocoding] search parse error: $e');
      return null;
    }
  }
}
