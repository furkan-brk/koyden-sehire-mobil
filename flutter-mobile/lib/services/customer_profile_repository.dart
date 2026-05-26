import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/customer_profile_model.dart';

class CustomerProfileRepository {
  final ApiClient _api;
  CustomerProfileRepository(this._api);

  Future<CustomerProfileModel> get() {
    return _api.get(
      ApiEndpoints.customerProfile,
      parse: (env) {
        final data =
            ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ?? {};
        return CustomerProfileModel.fromJson(data);
      },
    );
  }

  Future<CustomerProfileModel> update({
    required String fullName,
    String? email,
  }) {
    return _api.put(
      ApiEndpoints.customerProfile,
      data: {
        'full_name': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
      parse: (env) {
        final data =
            ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ?? {};
        return CustomerProfileModel.fromJson(data);
      },
    );
  }
}
