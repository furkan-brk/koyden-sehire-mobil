import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';

/// Dedicated admin login at `/login/admin`. Registered in the router
/// only when [kIsWeb] is true — on mobile the route doesn't exist and
/// the URL falls through to the global 404 errorBuilder.
///
/// Uses the same POST /auth/login endpoint, but rejects non-admin
/// roles client-side: if a farmer/customer somehow logs in here we
/// log them out and surface an error.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

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
      if (s == AuthStatus.admin) {
        context.go('/admin/dashboard');
        return;
      }
      // Non-admin logged in via the admin screen — reject.
      if (s == AuthStatus.farmerActive || s == AuthStatus.customerActive) {
        _auth.logout();
        context.snack(
          'Bu sayfa yalnızca yöneticiler içindir.',
          isError: true,
        );
      }
    });
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    _statusWorker?.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _auth.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetici Girişi')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 72,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Yönetici Girişi',
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu giriş ekranı yalnızca platform yöneticileri içindir.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      label: 'Telefon (05XXXXXXXXX)',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: Validators.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Şifre',
                      controller: _passwordController,
                      obscureText: _obscure,
                      validator: Validators.password,
                      textInputAction: TextInputAction.done,
                      suffix: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? true),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: Text(
                            'Beni Hatırla',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Obx(() => AppButton(
                          label: 'Giriş Yap',
                          isLoading: _auth.isSubmitting.value,
                          onPressed:
                              _auth.isSubmitting.value ? null : _submit,
                        )),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Not: Yönetici paneli yalnızca web üzerinden çalışır.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
