import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  AuthService get _auth => Get.find<AuthService>();

  Worker? _errorWorker;
  Worker? _statusWorker;

  @override
  void initState() {
    super.initState();
    // Surface any error already set on the auth service (e.g. account was
    // suspended at bootstrap and the splash redirected us here). The `ever`
    // worker below only fires on subsequent changes, so the initial value
    // would otherwise be silently dropped.
    final initialError = _auth.errorMessage.value;
    if (initialError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.snack(initialError, isError: true);
        _auth.clearError();
      });
    }
    _errorWorker = ever<String?>(_auth.errorMessage, (msg) {
      if (msg != null && mounted) {
        context.snack(msg, isError: true);
      }
    });
    _statusWorker = ever<AuthStatus>(_auth.status, (s) {
      if (!mounted) return;
      if (s == AuthStatus.farmerActive) {
        context.go('/farmer/dashboard');
      } else if (s == AuthStatus.customerActive) {
        context.go('/');
      } else if (s == AuthStatus.admin) {
        // Admin should NOT log in from the public /login screen. Surface an
        // error and force logout — admins must use /login/admin (web only).
        _auth.logout();
        context.snack(
          'Yönetici hesabıyla giriş yapamazsınız. Lütfen yönetici paneline '
          'gidin.',
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
    );
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
                    Icons.eco,
                    size: 48,
                    color: cs.primaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Köyden Şehre',
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Üretici veya müşteri olarak giriş yapın',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
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
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Şifremi Unuttum'),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => AppButton(
                      label: 'Giriş Yap',
                      isLoading: _auth.isSubmitting.value,
                      onPressed: _auth.isSubmitting.value ? null : _submit,
                    )),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Hesabın yok mu? Kayıt ol'),
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
