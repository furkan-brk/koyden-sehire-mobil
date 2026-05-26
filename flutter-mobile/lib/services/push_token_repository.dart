import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';

class PushTokenRepository {
  final ApiClient _api;
  PushTokenRepository(this._api);

  Future<void> registerFarmer(String token, String platform) async {
    await _api.post<void>(
      ApiEndpoints.farmerPushToken,
      data: {'token': token, 'platform': platform},
      parse: (_) {},
    );
  }

  Future<void> registerCustomer(String token, String platform) async {
    await _api.post<void>(
      ApiEndpoints.customerPushToken,
      data: {'token': token, 'platform': platform},
      parse: (_) {},
    );
  }

  Future<void> unregisterFarmer(String token) async {
    await _api.delete<void>(
      ApiEndpoints.farmerPushToken,
      data: {'token': token},
      parse: (_) {},
    );
  }

  Future<void> unregisterCustomer(String token) async {
    await _api.delete<void>(
      ApiEndpoints.customerPushToken,
      data: {'token': token},
      parse: (_) {},
    );
  }
}
