import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/otp_input.dart';
import 'package:koyden_sehire/services/otp_repository.dart';
import 'package:koyden_sehire/controllers/otp_controller.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _code = '';
  late final OtpController _ctrl;
  final OtpInputController _otpInput = OtpInputController();
  Worker? _errorWorker;

  @override
  void initState() {
    super.initState();
    // Lazily register the controller for this route.
    _ctrl = Get.put(OtpController(Get.find<OtpRepository>()));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ctrl.send(widget.phone);
      await _tryPasteFromClipboard();
    });
    // Shake whenever verify produces an error message.
    _errorWorker = ever<String?>(_ctrl.errorMessage, (msg) {
      if (msg != null && mounted) _otpInput.shake();
    });
  }

  Future<void> _tryPasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == AppConstants.otpLength && mounted) {
        _otpInput.setValue(digits);
        setState(() => _code = digits);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Panodan yapıştırıldı'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // Clipboard access can fail silently on some platforms — ignore.
    }
  }

  @override
  void dispose() {
    _errorWorker?.dispose();
    Get.delete<OtpController>();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length != AppConstants.otpLength) return;
    final ok = await _ctrl.verify(phone: widget.phone, code: _code);
    if (!mounted) return;
    if (ok) {
      // Return verified=true to caller (application form).
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = PhoneFormatter.mask(widget.phone);
    const totalCooldown = AppConstants.otpResendCooldownSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Telefon Doğrulama')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text('Telefon Doğrulama', style: context.text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '$masked numarasına 6 haneli doğrulama kodu gönderdik.',
                style: context.text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Obx(() => OtpInput(
                    length: AppConstants.otpLength,
                    controller: _otpInput,
                    onChanged: (v) => setState(() => _code = v),
                    onCompleted: (_) => _verify(),
                    enabled: !_ctrl.isVerifying.value,
                    errorText: _ctrl.errorMessage.value,
                  )),
              const SizedBox(height: 24),
              Obx(() => AppButton(
                    label: 'Doğrula',
                    isLoading: _ctrl.isVerifying.value,
                    onPressed: _code.length == AppConstants.otpLength
                        ? _verify
                        : null,
                  )),
              const SizedBox(height: 16),
              Obx(() {
                final cooldown = _ctrl.cooldownSeconds.value;
                if (cooldown > 0) {
                  final progress =
                      ((totalCooldown - cooldown) / totalCooldown)
                          .clamp(0.0, 1.0);
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.outlineVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kodu tekrar gönder ($cooldown sn)',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                return Center(
                  child: TextButton(
                    onPressed: _ctrl.isSending.value
                        ? null
                        : () => _ctrl.send(widget.phone),
                    child: const Text('Kodu Tekrar Gönder'),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
