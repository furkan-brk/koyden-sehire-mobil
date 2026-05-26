import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/models/category_model.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';

const _kLabels = <String, String>{
  'sebze': 'Taze Sebze',
  'sut-urunleri': 'Süt ve Yumurta',
  'yumurta': 'Yumurta',
  'bal-ari-urunleri': 'Bal ve Reçel',
  'zeytin-zeytinyagi': 'Doğal Yağlar',
  'baklagil-tahil': 'Bakliyat',
  'kuruyemis': 'Kuruyemiş',
  'dogal-urunler': 'Doğal Ürünler',
  'meyve': 'Meyve',
};

const _kIcons = <String, IconData>{
  'sebze': Icons.eco,
  'sut-urunleri': Icons.water_drop,
  'yumurta': Icons.egg,
  'bal-ari-urunleri': Icons.local_florist,
  'zeytin-zeytinyagi': Icons.opacity,
  'baklagil-tahil': Icons.grain,
  'kuruyemis': Icons.spa,
  'dogal-urunler': Icons.park,
  'meyve': Icons.apple,
};

const _kBgColors = <String, Color>{
  'sebze': Color(0xFFDEF5E8),
  'sut-urunleri': Color(0xFFDCEFFD),
  'yumurta': Color(0xFFFFF8D6),
  'bal-ari-urunleri': Color(0xFFFFF3CC),
  'zeytin-zeytinyagi': Color(0xFFE4F5E2),
  'baklagil-tahil': Color(0xFFF6EDD6),
  'kuruyemis': Color(0xFFFDE9D8),
  'dogal-urunler': Color(0xFFEDE5FA),
  'meyve': Color(0xFFFFE0E8),
};

const _kIconColors = <String, Color>{
  'sebze': Color(0xFF1E6B40),
  'sut-urunleri': Color(0xFF1255A0),
  'yumurta': Color(0xFF8B6914),
  'bal-ari-urunleri': Color(0xFF7A5210),
  'zeytin-zeytinyagi': Color(0xFF1E5C28),
  'baklagil-tahil': Color(0xFF6B4A12),
  'kuruyemis': Color(0xFF7A3010),
  'dogal-urunler': Color(0xFF4A2E90),
  'meyve': Color(0xFF8B143C),
};

const _kDefaultBg = Color(0xFFF0F4EF);
const _kDefaultIconColor = AppColors.primaryContainer;

class ProductCategoryScreen extends StatelessWidget {
  const ProductCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catCtrl = Get.find<CategoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürünler'),
        leading: context.canPop()
            ? const BackButton()
            : null,
      ),
      bottomNavigationBar:
          const CustomerBottomNav(current: CustomerTab.market),
      body: SafeArea(
        child: Obx(() {
          if (catCtrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final roots = catCtrl.categories.where((c) => c.isRoot).toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kategorileri Keşfet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yerel üreticilerden taze, doğal ve özenle hazırlanmış ürünler.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                _AllCategoriesButton(
                  onTap: () => context.push('/products'),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: roots.isEmpty
                      ? const SizedBox.shrink()
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 104,
                          ),
                          itemCount: roots.length,
                          itemBuilder: (_, i) => _CategoryCard(
                            category: roots[i],
                            onTap: () => context.push(
                              '/products?category_id=${roots[i].id}',
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _AllCategoriesButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AllCategoriesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: AppColors.primaryFixed.withAlpha(60),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withAlpha(120),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tüm Kategoriler',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final slug = category.slug;
    final label = _kLabels[slug] ?? category.name;
    final icon = _kIcons[slug] ?? Icons.category_outlined;
    final bg = _kBgColors[slug] ?? _kDefaultBg;
    final iconColor = _kIconColors[slug] ?? _kDefaultIconColor;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
