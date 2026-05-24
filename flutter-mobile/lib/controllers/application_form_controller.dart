import 'dart:io';

import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/services/application_repository.dart';
import 'package:koyden_sehire/models/application_model.dart';

class ApplicationFormController extends GetxController {
  final ApplicationRepository _repo;
  ApplicationFormController(this._repo);

  final Rxn<InviteInfo> invite = Rxn<InviteInfo>();
  final Rx<ApplicationFormData> data = const ApplicationFormData().obs;
  final RxInt currentStep = 0.obs; // 0..4
  final RxBool phoneVerified = false.obs;
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool submitted = false.obs;

  void setInvite(InviteInfo info) {
    invite.value = info;
  }

  void updateData(ApplicationFormData Function(ApplicationFormData d) update) {
    data.value = update(data.value);
  }

  void setPhoneVerified(bool verified) {
    phoneVerified.value = verified;
  }

  void goToStep(int step) {
    currentStep.value = step;
  }

  void next() {
    if (currentStep.value < 3) currentStep.value = currentStep.value + 1;
  }

  void previous() {
    if (currentStep.value > 0) currentStep.value = currentStep.value - 1;
  }

  void reset() {
    invite.value = null;
    data.value = const ApplicationFormData();
    currentStep.value = 0;
    phoneVerified.value = false;
    isUploading.value = false;
    uploadProgress.value = 0;
    isSubmitting.value = false;
    errorMessage.value = null;
    submitted.value = false;
  }

  Future<bool> uploadVideo(File file, {String contentType = 'video/mp4'}) async {
    final inv = invite.value;
    if (inv == null) return false;
    isUploading.value = true;
    uploadProgress.value = 0;
    errorMessage.value = null;
    try {
      final presigned = await _repo.getVideoPresignedUrl(
        phone: data.value.phone,
        inviteCode: inv.code,
        contentType: contentType,
      );
      if (presigned.uploadUrl.isEmpty) {
        // No-op storage provider in dev — accept gracefully and skip upload.
        errorMessage.value =
            'Sunucuda video depolama yapılandırılmamış. Şimdilik geçebilirsiniz.';
        isUploading.value = false;
        return false;
      }
      await _repo.uploadVideoToPresigned(
        uploadUrl: presigned.uploadUrl,
        file: file,
        contentType: contentType,
        onProgress: (sent, total) {
          if (total > 0) uploadProgress.value = sent / total;
        },
      );
      uploadProgress.value = 1;
      data.value =
          data.value.copyWith(applicationVideoKey: presigned.key);
      isUploading.value = false;
      return true;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      isUploading.value = false;
      return false;
    } catch (_) {
      errorMessage.value = 'Video yüklenemedi';
      isUploading.value = false;
      return false;
    }
  }

  Future<bool> submit() async {
    final inv = invite.value;
    if (inv == null) return false;
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      await _repo.submit(inviteCode: inv.code, data: data.value);
      isSubmitting.value = false;
      submitted.value = true;
      return true;
    } on AppException catch (e) {
      String msg = e.message;
      if (e.code == 'CONFLICT') {
        msg =
            'Bu telefon numarasıyla aktif bir başvuru bulunuyor veya kayıtlı bir hesap mevcut.';
      }
      errorMessage.value = msg;
      isSubmitting.value = false;
      return false;
    } catch (_) {
      errorMessage.value = 'Başvuru gönderilemedi';
      isSubmitting.value = false;
      return false;
    }
  }
}
