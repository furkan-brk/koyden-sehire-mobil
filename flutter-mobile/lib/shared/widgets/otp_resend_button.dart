import 'dart:async';

import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';

/// Countdown-then-resend button for OTP screens.
///
/// Auto-starts a [AppConstants.otpResendCooldownSeconds]-second countdown when
/// first mounted (because the OTP was just dispatched). While counting down it
/// shows grey text; once the timer expires it shows a tappable [TextButton].
///
/// Tapping the button disables it, calls [onResend], and — once the future
/// resolves — restarts the countdown. This means the widget is fully
/// self-contained: callers only need to supply the resend async callback.
///
/// Usage:
/// ```dart
/// OtpResendButton(onResend: () => _auth.requestRegisterOtp(phone))
/// ```
class OtpResendButton extends StatefulWidget {
  /// Called when the user taps "Kodu Tekrar Gönder". May be `null` to keep
  /// the button permanently disabled (e.g., while the parent is loading).
  final Future<void> Function()? onResend;

  const OtpResendButton({super.key, required this.onResend});

  @override
  State<OtpResendButton> createState() => _OtpResendButtonState();
}

class _OtpResendButtonState extends State<OtpResendButton> {
  int _cooldown = 0;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = AppConstants.otpResendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldown = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _handleResend() async {
    if (widget.onResend == null || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onResend!();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _startCooldown();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cooldown > 0) {
      return Text(
        'Kodu tekrar gönder ($_cooldown)',
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      );
    }
    return TextButton(
      onPressed: (_sending || widget.onResend == null) ? null : _handleResend,
      child: _sending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Kodu Tekrar Gönder'),
    );
  }
}
