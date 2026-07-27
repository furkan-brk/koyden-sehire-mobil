import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

enum AppButtonVariant { primary, secondary, destructive, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool fullWidth;
  final Widget? icon;

  /// Set when the button sits on a dark surface (ör. AppColors.primary zemin).
  /// Varsayılan tema renkleri (primaryContainer) böyle bir zeminde neredeyse
  /// okunmuyor; bu bayrak secondary/text varyantlarını beyaza çevirir.
  final bool onDark;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.icon,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: disabled ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: onDark
              ? OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                )
              : null,
          child: child,
        );
        break;
      case AppButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: disabled ? null : onPressed,
          style: onDark
              ? TextButton.styleFrom(foregroundColor: Colors.white)
              : null,
          child: child,
        );
        break;
    }

    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}
