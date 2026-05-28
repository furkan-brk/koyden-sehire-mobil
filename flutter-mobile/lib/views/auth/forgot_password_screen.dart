import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/auth/forgot_password_controller.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';

/// First step of the password-reset flow: collect the phone number and ask
/// the backend to send a reset OTP. On success the user is forwarded to
/// [ResetPasswordScreen] with the phone preserved as a query parameter so
/// deep links and refreshes keep working.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  ForgotPasswordController get _ctrl =>
      Get.find<ForgotPasswordController>();

  @override
  void initState() {
    super.initState();
    // Reset transient flags so a previous successful flow doesn't show
    // stale info messages here.
    _ctrl.reset();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    final ok = await _ctrl.requestReset(phone);
    if (!mounted) return;
    if (ok) {
      final info = _ctrl.infoMessage.value;
      if (info != null) context.snack(info);
      context.push('/reset-password?phone=$phone');
    } else {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: null,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Icon(
                    Icons.lock_reset,
                    size: 48,
                    color: cs.primaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Şifremi Unuttum',
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Telefon numaranızı girin, SMS ile şifre sıfırlama kodu '
                  'göndereceğiz.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'Telefon (05XXXXXXXXX)',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: Validators.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                Obx(() => AppButton(
                      label: 'OTP Gönder',
                      isLoading: _ctrl.isSending.value,
                      onPressed: _ctrl.isSending.value ? null : _submit,
                    )),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Girişe Dön'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
