import 'dart:io';

import 'package:get/get.dart';

import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/core/services/draft_service.dart';
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

  DraftService? get _drafts =>
      Get.isRegistered<DraftService>() ? Get.find<DraftService>() : null;

  void setInvite(InviteInfo info) {
    invite.value = info;
  }

  void updateData(ApplicationFormData Function(ApplicationFormData d) update) {
    data.value = update(data.value);
    // Fire-and-forget draft persistence whenever wizard state mutates.
    _persistDraft();
  }

  void setPhoneVerified(bool verified) {
    phoneVerified.value = verified;
    _persistDraft();
  }

  void goToStep(int step) {
    currentStep.value = step;
    _persistDraft();
  }

  void next() {
    if (currentStep.value < 3) currentStep.value = currentStep.value + 1;
    _persistDraft();
  }

  void previous() {
    if (currentStep.value > 0) currentStep.value = currentStep.value - 1;
    _persistDraft();
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

  // ── Draft persistence ──────────────────────────────────────────────

  void _persistDraft() {
    final svc = _drafts;
    if (svc == null) return;
    // ignore: discarded_futures
    svc.saveDraft({
      'data': data.value.toDraftJson(),
      'step': currentStep.value,
      'phone_verified': phoneVerified.value,
      'invite_code': invite.value?.code,
      'invite_inviter_name': invite.value?.inviterName,
      'invite_max_uses': invite.value?.maxUses,
      'invite_used_count': invite.value?.usedCount,
    });
  }

  /// Returns whether a draft exists in local storage.
  Future<bool> hasDraft() async => (await _drafts?.hasDraft()) ?? false;

  /// Loads an existing draft into the controller. Returns false if none
  /// existed or the draft was unreadable.
  Future<bool> restoreDraft() async {
    final svc = _drafts;
    if (svc == null) return false;
    final raw = await svc.loadDraft();
    if (raw == null) return false;
    final dataMap = raw['data'];
    if (dataMap is Map) {
      data.value = ApplicationFormData.fromDraftJson(
        Map<String, dynamic>.from(
          dataMap.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
    }
    final step = raw['step'];
    if (step is int) currentStep.value = step.clamp(0, 3);
    phoneVerified.value = raw['phone_verified'] == true;
    final code = raw['invite_code']?.toString();
    if (code != null && code.isNotEmpty && invite.value == null) {
      invite.value = InviteInfo(
        code: code,
        inviterName: raw['invite_inviter_name']?.toString(),
        maxUses: (raw['invite_max_uses'] as num?)?.toInt() ?? 0,
        usedCount: (raw['invite_used_count'] as num?)?.toInt() ?? 0,
      );
    }
    return true;
  }

  Future<void> clearDraft() async => _drafts?.clearDraft();

  // ── Network ────────────────────────────────────────────────────────

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
      _persistDraft();
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
      // Successfully sent — wipe the local draft so the user is not asked
      // to resume on next launch.
      await clearDraft();
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
