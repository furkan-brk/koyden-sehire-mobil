import 'package:koyden_sehire/core/api/api_client.dart';
import 'package:koyden_sehire/core/api/api_endpoints.dart';
import 'package:koyden_sehire/models/farmer_profile_edit_model.dart';

class FarmerProfileRepository {
  final ApiClient _api;
  FarmerProfileRepository(this._api);

  Future<FarmerProfileEdit> get() {
    return _api.get(
      ApiEndpoints.farmerProfile,
      parse: (env) {
        // Backend envelope: { data: { user: {...}, profile: {...} } }.
        // City/district/village/display_name live under `profile`; some
        // fields (e.g. phone) may sit under `user`. Merge user → profile so
        // profile values win on conflict.
        final root = ((env as Map)['data'] as Map?)?.cast<String, dynamic>() ??
            const {};
        final profile =
            (root['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
        final user =
            (root['user'] as Map?)?.cast<String, dynamic>() ?? const {};
        final merged = <String, dynamic>{...user, ...profile};
        return FarmerProfileEdit.fromJson(merged);
      },
    );
  }

  Future<void> update(FarmerProfileEdit profile) async {
    await _api.put(
      ApiEndpoints.farmerProfile,
      data: profile.toJson(),
      parse: (_) => null,
    );
  }
}
