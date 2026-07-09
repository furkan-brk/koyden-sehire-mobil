import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:koyden_sehire/shared/extensions/context_extensions.dart';

/// Requests [permissions] at the point of use and returns true only when all
/// are granted. If any is permanently denied, shows a snackbar with an
/// "Ayarlar" action that deep-links to the app settings.
Future<bool> ensurePermissions(
  BuildContext context,
  List<Permission> permissions, {
  required String deniedMessage,
}) async {
  if (kIsWeb) return true;

  var allGranted = true;
  var permanentlyDenied = false;
  for (final permission in permissions) {
    final status = await permission.request();
    if (!status.isGranted) allGranted = false;
    if (status.isPermanentlyDenied) permanentlyDenied = true;
  }

  if (permanentlyDenied && context.mounted) {
    context.snack(
      deniedMessage,
      isError: true,
      actionLabel: 'Ayarlar',
      onAction: () {
        openAppSettings();
      },
    );
  }
  return allGranted;
}
