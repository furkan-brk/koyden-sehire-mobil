import 'package:flutter/material.dart';

/// Layout breakpoints (logical px).
class AppBreakpoints {
  AppBreakpoints._();
  static const double compact = 360; // çok dar telefonlar
  static const double medium = 560; // admin dashboard stat ladder
  static const double desktop = 900; // admin tablo / two-pane layout
  static const double shell = 1100; // admin side-rail shell
  static const double wide = 1200; // admin 6 kolonlu stat satırı
}

/// Grid boyut token'ları.
class AppGridTokens {
  AppGridTokens._();
  static const double productTileMax = 200; // hedef maks. ürün tile genişliği
  static const double farmerTileMax = 200;
  static const double categoryTileMax = 130;
  static const double gridSpacing = 12;
}

/// Sistem metin ölçeğinin extent hesapları için clamp'lenmiş çarpanı.
/// App root'ta withClampedTextScaling(max: 1.6) ile uyumlu.
double textScaleOf(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return scale.clamp(1.0, 1.6);
}

/// [tileWidth] genişliğindeki bir ProductCard'ın toplam yüksekliği.
/// Görsel AspectRatio(4/3) ile genişlikten, metin bloğu textScale'den türür.
double productCardExtent(
  BuildContext context,
  double tileWidth, {
  bool compact = false,
}) {
  final image = tileWidth * 3 / 4;
  final text = (compact ? 124.0 : 152.0) * textScaleOf(context);
  return image + text;
}

/// Ürün grid'leri için ortak delegate. [availableWidth] = grid genişliği
/// eksi kendi padding'i (tam ekran grid'lerde screenWidth - 32).
///
/// Kolon sayısı önce hesaplandığı için tile genişliği — dolayısıyla görsel
/// yüksekliği — kesin bilinir; mainAxisExtent her metin ölçeğinde kartı sığdırır.
SliverGridDelegateWithFixedCrossAxisCount productGridDelegate(
  BuildContext context,
  double availableWidth, {
  bool compact = false,
}) {
  final cols =
      (availableWidth / AppGridTokens.productTileMax).ceil().clamp(2, 4);
  final tileWidth =
      (availableWidth - (cols - 1) * AppGridTokens.gridSpacing) / cols;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    mainAxisSpacing: AppGridTokens.gridSpacing,
    crossAxisSpacing: AppGridTokens.gridSpacing,
    mainAxisExtent: productCardExtent(context, tileWidth, compact: compact),
  );
}

/// FarmerCard'ın avatar + metin bloğu yüksekliği (kart padding'i dahil).
/// Taban değer, eski sabit 208px yatay liste yüksekliğinden geliyor.
double farmerCardExtent(BuildContext context) =>
    208.0 * textScaleOf(context);

/// Üretici (FarmerCard) grid'leri için ortak delegate.
SliverGridDelegateWithFixedCrossAxisCount farmerGridDelegate(
  BuildContext context,
  double availableWidth,
) {
  final cols =
      (availableWidth / AppGridTokens.farmerTileMax).ceil().clamp(2, 4);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    mainAxisSpacing: AppGridTokens.gridSpacing,
    crossAxisSpacing: AppGridTokens.gridSpacing,
    mainAxisExtent: farmerCardExtent(context),
  );
}
