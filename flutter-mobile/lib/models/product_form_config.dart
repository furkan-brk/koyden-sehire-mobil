import 'package:flutter/material.dart';

// ─── Section Config ────────────────────────────────────────────────────────────

/// Bir form bölümünün (section) görsel metadatası.
class ProductFormSectionConfig {
  final String title;
  final IconData icon;

  /// Section başlığının hemen altında görünen yardımcı açıklama.
  final String subtitle;

  /// Zorunlu bölüm sayacına dahil edilip edilmeyeceği.
  final bool isRequired;

  const ProductFormSectionConfig({
    required this.title,
    required this.icon,
    required this.subtitle,
    this.isRequired = false,
  });
}

// ─── Field Config ──────────────────────────────────────────────────────────────

/// Bir metin alanının görsel metadatası.
class ProductFormFieldConfig {
  final String label;
  final String hint;

  /// Alan altında gösterilen ince yardımcı metin (helperText).
  final String? helperText;
  final int? maxLength;

  const ProductFormFieldConfig({
    required this.label,
    required this.hint,
    this.helperText,
    this.maxLength,
  });
}

// ─── Central Config ────────────────────────────────────────────────────────────

/// Ürün ekleme / düzenleme formunun tüm görsel konfigürasyonu.
/// Section başlıkları, ikonlar, alt açıklamalar ve alan metadata'sı buradan okunur.
class ProductFormConfig {
  ProductFormConfig._();

  // ── Bölümler ──────────────────────────────────────────────────────────────

  static const photos = ProductFormSectionConfig(
    title: 'Fotoğraflar',
    icon: Icons.photo_library_outlined,
    subtitle: 'Fotoğraf eklemek ürünü 3× daha görünür yapar',
    isRequired: false,
  );

  static const category = ProductFormSectionConfig(
    title: 'Kategori',
    icon: Icons.category_outlined,
    subtitle: 'Alıcıların sizi kolayca bulmasını sağlar',
    isRequired: true,
  );

  static const basicInfo = ProductFormSectionConfig(
    title: 'Ürün Bilgileri',
    icon: Icons.inventory_2_outlined,
    subtitle: 'Ürününüzü kısaca ve açık biçimde tanıtın',
    isRequired: true,
  );

  static const pricing = ProductFormSectionConfig(
    title: 'Fiyat & Birim',
    icon: Icons.payments_outlined,
    subtitle: 'Doğru fiyat belirleme satış sürecinizi hızlandırır',
    isRequired: true,
  );

  static const stock = ProductFormSectionConfig(
    title: 'Stok Durumu',
    icon: Icons.layers_outlined,
    subtitle: 'Alıcılar ürününüzün güncel durumunu görebilir',
    isRequired: true,
  );

  static const location = ProductFormSectionConfig(
    title: 'Konum',
    icon: Icons.location_on_outlined,
    subtitle: 'Profilinizdeki konum otomatik olarak kullanılır',
    isRequired: false,
  );

  // ── Alan konfigürasyonları ─────────────────────────────────────────────────

  static const titleField = ProductFormFieldConfig(
    label: 'Ürün Adı',
    hint: 'Örn. Organik Kırmızı Domates',
    helperText: 'Sade ve açıklayıcı bir isim tercih edin',
    maxLength: 255,
  );

  static const descriptionField = ProductFormFieldConfig(
    label: 'Açıklama',
    hint: 'Taze mi, organik mi, nasıl yetiştirildi? Alıcıyı bilgilendirin.',
  );

  static const priceField = ProductFormFieldConfig(
    label: 'Fiyat',
    hint: '0.00',
    helperText: 'Varsa toplama / teslimat maliyetini dahil edin',
  );

  /// Zorunlu bölüm sayısı — ilerleme çubuğu hesabında kullanılır.
  static const int requiredSectionCount = 4; // category, basicInfo, pricing, stock
}

// ─── Form Data ─────────────────────────────────────────────────────────────────

/// Ürün ekleme / düzenleme formunun anlık veri durumu.
/// [ProductFormController] tarafından reaktif state olarak tutulur.
class ProductFormData {
  final String title;
  final String description;
  final String price;
  final String unit;
  final String city;
  final String district;
  final String village;
  final String? categoryId;
  final String stockStatus;
  final List<String> imageUrls;

  const ProductFormData({
    this.title = '',
    this.description = '',
    this.price = '',
    this.unit = 'kg',
    this.city = '',
    this.district = '',
    this.village = '',
    this.categoryId,
    this.stockStatus = 'available',
    this.imageUrls = const [],
  });

  ProductFormData copyWith({
    String? title,
    String? description,
    String? price,
    String? unit,
    String? city,
    String? district,
    String? village,
    String? categoryId,
    String? stockStatus,
    List<String>? imageUrls,
  }) =>
      ProductFormData(
        title: title ?? this.title,
        description: description ?? this.description,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        city: city ?? this.city,
        district: district ?? this.district,
        village: village ?? this.village,
        categoryId: categoryId ?? this.categoryId,
        stockStatus: stockStatus ?? this.stockStatus,
        imageUrls: imageUrls ?? this.imageUrls,
      );

  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        'description': description.trim(),
        'price': num.tryParse(price.replaceAll(',', '.')) ?? 0,
        'unit': unit,
        'city': city.trim(),
        'district': district.trim(),
        'village': village.trim(),
        if (categoryId != null) 'category_id': categoryId,
        'stock_status': stockStatus,
        'image_urls': imageUrls,
      };
}

// ─── Units ─────────────────────────────────────────────────────────────────────

const List<String> productUnits = [
  'kg',
  'gram',
  'adet',
  'litre',
  'kasa',
  'koli',
  'demet',
  'paket',
];
