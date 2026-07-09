import 'package:flutter/material.dart';

import 'package:koyden_sehire/shared/utils/responsive.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => theme.textTheme;
  ColorScheme get colors => theme.colorScheme;
  MediaQueryData get mq => MediaQuery.of(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompactPhone => screenWidth < AppBreakpoints.compact;
  bool get isDesktopWidth => screenWidth >= AppBreakpoints.desktop;
  // Not: metin ölçeği için textScaleOf(context) kullanın — GetX'in
  // ContextExtensionss.textScale üyesiyle çakıştığından getter eklenmedi.

  void toast(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void snack(
    String message, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? colors.error : null,
          behavior: SnackBarBehavior.floating,
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: isError ? colors.onError : null,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }
}
