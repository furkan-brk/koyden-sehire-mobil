import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/auth/forgot_password_controller.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/shared/widgets/otp_input.dart';

/// Second step of the password-reset flow. Expects the phone to arrive
/// either via the constructor (from a direct push) or via the `phone`
/// query parameter set by [ForgotPasswordScreen].
class ResetPasswordScreen extends StatefulWidget {
  final String phone;
  const ResetPasswordScreen({super.key, required this.phone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final OtpInputController _otpInput = OtpInputController();

  String _otp = '';
  bool _obscure = true;
  Worker? _errorWorker;

  ForgotPasswordController get _ctrl =>
      Get.find<ForgotPasswordController>();

  @override
  void initState() {
    super.initState();
    _errorWorker = ever<String?>(_ctrl.errorMessage, (msg) {
      if (msg != null && mounted) _otpInput.shake();
    });
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Şifre zorunludur';
    if (v.length < 8) return 'Şifre en az 8 karakter olmalı';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Şifreyi tekrar girin';
    if (v != _passwordController.text) return 'Şifreler eşleşmiyor';
    return null;
  }

  Future<void> _submit() async {
    if (_otp.length != AppConstants.otpLength) {
      context.snack('Lütfen 6 haneli kodu girin', isError: true);
      _otpInput.shake();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await _ctrl.confirmReset(
      phoneNumber: widget.phone,
      otp: _otp,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      context.snack('Şifreniz güncellendi. Lütfen giriş yapın.');
      context.go('/login');
    } else {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  Future<void> _resend() async {
    final ok = await _ctrl.requestReset(widget.phone);
    if (!mounted) return;
    if (ok) {
      context.snack('Yeni kod gönderildi');
    } else {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final masked = PhoneFormatter.mask(widget.phone);
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
                    Icons.password,
                    size: 48,
                    color: cs.primaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Yeni Şifre Belirle',
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$masked numarasına gönderilen 6 haneli kodu ve yeni '
                  'şifrenizi girin.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Obx(() => OtpInput(
                      length: AppConstants.otpLength,
                      controller: _otpInput,
                      onChanged: (v) => setState(() => _otp = v),
                      enabled: !_ctrl.isSubmitting.value,
                      errorText: _ctrl.errorMessage.value,
                    )),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Yeni Şifre (en az 8 karakter)',
                  controller: _passwordController,
                  obscureText: _obscure,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.next,
                  suffix: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Yeni Şifre (Tekrar)',
                  controller: _confirmController,
                  obscureText: _obscure,
                  validator: _validateConfirm,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                Obx(() => AppButton(
                      label: 'Şifreyi Sıfırla',
                      isLoading: _ctrl.isSubmitting.value,
                      onPressed: _ctrl.isSubmitting.value ? null : _submit,
                    )),
                const SizedBox(height: 12),
                Center(
                  child: Obx(() => TextButton(
                        onPressed: _ctrl.isSending.value ? null : _resend,
                        child: Text(_ctrl.isSending.value
                            ? 'Gönderiliyor…'
                            : 'Kodu Tekrar Gönder'),
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
