import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/shared/widgets/otp_input.dart';
import 'package:koyden_sehire/shared/widgets/otp_resend_button.dart';

/// Multi-step customer registration: phone → OTP → profile.
///
/// Backend contract:
///   1. POST /otp/send {phone}              — sends 6-digit code
///   2. POST /otp/verify {phone, code}      — sets otp_verified:{phone} for 30m
///   3. POST /auth/register/customer        — consumes otp_verified marker
///
/// Steps are kept local to this widget so users can step back without
/// losing earlier input. On success the AuthService publishes
/// AuthStatus.customerActive and the router redirects to `/`.
class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

enum _Step { phone, otp, profile }

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Step _step = _Step.phone;
  bool _obscure = true;
  String _otpCode = '';

  AuthService get _auth => Get.find<AuthService>();

  Worker? _errorWorker;
  Worker? _statusWorker;

  @override
  void initState() {
    super.initState();
    _errorWorker = ever<String?>(_auth.errorMessage, (msg) {
      if (msg != null && mounted) {
        context.snack(msg, isError: true);
      }
    });
    _statusWorker = ever<AuthStatus>(_auth.status, (s) {
      if (!mounted) return;
      if (s == AuthStatus.customerActive) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    _statusWorker?.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await _auth.requestRegisterOtp(_phoneController.text.trim());
    if (ok && mounted) {
      setState(() {
        _step = _Step.otp;
        _otpCode = '';
      });
      context.snack('Doğrulama kodu gönderildi');
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != AppConstants.otpLength) return;
    FocusScope.of(context).unfocus();
    final ok = await _auth.verifyRegisterOtp(
      _phoneController.text.trim(),
      _otpCode,
    );
    if (ok && mounted) {
      setState(() => _step = _Step.profile);
    }
  }

  Future<void> _resendOtp() async {
    await _auth.requestRegisterOtp(_phoneController.text.trim());
  }

  Future<void> _submitProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _auth.registerCustomer(
      phone: _phoneController.text.trim(),
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    // Status listener will navigate to '/' on success.
  }

  String? _validateEmailRequired(String? v) {
    if (v == null || v.trim().isEmpty) return 'E-posta zorunludur';
    final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]+$').hasMatch(v.trim());
    return ok ? null : 'Geçerli bir e-posta girin';
  }

  String? _validateStrongPassword(String? v) {
    if (v == null || v.isEmpty) return 'Şifre zorunludur';
    if (v.length < 8) return 'Şifre en az 8 karakter olmalı';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _step == _Step.phone
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _step = _step == _Step.profile ? _Step.otp : _Step.phone;
                }),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.phone => _buildPhoneStep(),
            _Step.otp => _buildOtpStep(),
            _Step.profile => _buildProfileStep(),
          },
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeader(
            step: 1,
            total: 3,
            title: 'Telefon numaranızı girin',
            subtitle:
                'SMS ile 6 haneli doğrulama kodu göndereceğiz. Numara hesabınızla ilişkilendirilecek.',
          ),
          const SizedBox(height: 24),
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
                label: 'Kod Gönder',
                isLoading: _auth.isSubmitting.value,
                onPressed: _auth.isSubmitting.value ? null : _sendOtp,
              )),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          step: 2,
          total: 3,
          title: 'Doğrulama kodunu girin',
          subtitle:
              '${_phoneController.text} numarasına gönderdiğimiz 6 haneli kodu girin.',
        ),
        const SizedBox(height: 32),
        OtpInput(
          length: AppConstants.otpLength,
          onChanged: (v) => setState(() => _otpCode = v),
          onCompleted: (v) {
            _otpCode = v;
            _verifyOtp();
          },
        ),
        const SizedBox(height: 24),
        Obx(() => AppButton(
              label: 'Doğrula',
              isLoading: _auth.isSubmitting.value,
              onPressed: (_otpCode.length == AppConstants.otpLength &&
                      !_auth.isSubmitting.value)
                  ? _verifyOtp
                  : null,
            )),
        const SizedBox(height: 12),
        Center(child: OtpResendButton(onResend: _resendOtp)),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeader(
            step: 3,
            total: 3,
            title: 'Bilgilerinizi tamamlayın',
            subtitle: 'Hesabınızı oluşturmak için son birkaç bilgi.',
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Ad Soyad',
            controller: _nameController,
            validator: (v) => Validators.required(v, field: 'Ad Soyad'),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'E-posta',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmailRequired,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Şifre (en az 8 karakter)',
            controller: _passwordController,
            obscureText: _obscure,
            validator: _validateStrongPassword,
            textInputAction: TextInputAction.done,
            suffix: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => AppButton(
                label: 'Hesabı Oluştur',
                isLoading: _auth.isSubmitting.value,
                onPressed: _auth.isSubmitting.value ? null : _submitProfile,
              )),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: step / total,
            minHeight: 6,
            color: cs.primaryContainer,
            backgroundColor: cs.surfaceContainerHigh,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Adım $step / $total',
          style: context.text.labelMedium?.copyWith(
            color: cs.primaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: context.text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: context.text.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
