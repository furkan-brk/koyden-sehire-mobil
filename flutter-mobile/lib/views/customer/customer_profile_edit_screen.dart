import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/customer/customer_profile_controller.dart';
import 'package:koyden_sehire/core/utils/validators.dart' show Validators;
import 'package:koyden_sehire/models/customer_profile_model.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';

class CustomerProfileEditScreen extends StatefulWidget {
  const CustomerProfileEditScreen({super.key});

  @override
  State<CustomerProfileEditScreen> createState() =>
      _CustomerProfileEditScreenState();
}

class _CustomerProfileEditScreenState
    extends State<CustomerProfileEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();
  Worker? _profileWorker;
  bool _formInitialized = false;

  CustomerProfileController get _ctrl =>
      Get.find<CustomerProfileController>();

  @override
  void initState() {
    super.initState();
    final p = _ctrl.profile.value;
    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    if (p == null) {
      _profileWorker = ever<CustomerProfileModel?>(
        _ctrl.profile,
        (profile) {
          if (profile != null && !_formInitialized) {
            _nameCtrl.text = profile.fullName;
            _emailCtrl.text = profile.email ?? '';
            _formInitialized = true;
            _profileWorker?.dispose();
            _profileWorker = null;
          }
        },
      );
    } else {
      _formInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _profileWorker?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim();
    final ok = await _ctrl.updateProfile(
      fullName: _nameCtrl.text.trim(),
      email: email.isEmpty ? null : email,
    );
    if (!mounted) return;
    if (ok) {
      context.toast('Profil güncellendi');
      if (context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Bilgileri'),
      ),
      body: Obx(() {
        final profile = _ctrl.profile.value;
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Ad Soyad',
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'En az 2 karakter giriniz';
                      }
                      if (v.trim().length > 100) {
                        return 'En fazla 100 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'E-posta (isteğe bağlı)',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return Validators.email(v.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  if (profile != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              color: AppColors.onSurfaceVariant, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Telefon',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.onSurfaceVariant),
                                ),
                                Text(
                                  profile.phone,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Değiştirilemez',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Obx(() => AppButton(
                        label: 'Kaydet',
                        isLoading: _ctrl.isSaving.value,
                        onPressed: _ctrl.isSaving.value ? null : _save,
                      )),
                  Obx(() {
                    final err = _ctrl.errorMessage.value;
                    if (err == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err,
                          style: const TextStyle(color: AppColors.error)),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Bilgi notu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                    color: cs.primaryContainer.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Telefon numaranız hesabınıza bağlı olduğu için değiştirilemez.',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
