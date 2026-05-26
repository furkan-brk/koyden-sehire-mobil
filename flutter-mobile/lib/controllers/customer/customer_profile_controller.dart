import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/customer_profile_model.dart';
import 'package:koyden_sehire/services/customer_profile_repository.dart';

class CustomerProfileController extends GetxController {
  final CustomerProfileRepository _repo;
  CustomerProfileController(this._repo);

  final Rxn<CustomerProfileModel> profile = Rxn();
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      profile.value = await _repo.get();
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Profil yüklenemedi';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updateProfile({required String fullName, String? email}) async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repo.update(fullName: fullName, email: email);
      profile.value = updated;
      // Sync the display name in AuthService so the AppBar also updates.
      Get.find<AuthService>().displayName.value = updated.fullName;
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Güncelleme başarısız oldu';
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
