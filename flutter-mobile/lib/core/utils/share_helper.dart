import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:koyden_sehire/shared/extensions/context_extensions.dart';

class ShareHelper {
  /// Sistem paylaşım sayfasını açar.
  ///
  /// Paylaşım açılamazsa (eksik plugin, chooser bulunamadı, web'de
  /// `navigator.share` desteklenmiyor vb.) metni panoya kopyalar ve kullanıcıyı
  /// bilgilendirir — sessiz başarısızlık bırakmaz.
  static Future<void> shareText(BuildContext context, String text) async {
    try {
      await Share.share(text, sharePositionOrigin: _originOf(context));
    } catch (e, st) {
      debugPrint('[ShareHelper] paylaşım başarısız: $e\n$st');
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      context.snack('Paylaşım açılamadı, metin panoya kopyalandı',
          isError: true);
    }
  }

  /// iPad/macOS'ta paylaşım popover'ının çapası. Kutu bulunamazsa `null`.
  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
