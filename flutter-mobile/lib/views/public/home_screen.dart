import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/shared/utils/responsive.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/category_chip.dart';
import 'package:koyden_sehire/shared/widgets/farmer_card.dart';
import 'package:koyden_sehire/shared/widgets/farmer_mode_chip.dart';
import 'package:koyden_sehire/shared/widgets/product_card.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:shimmer/shimmer.dart';
import 'package:koyden_sehire/shared/widgets/shimmer_product_card.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/models/category_model.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/controllers/public/home_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catCtrl = Get.find<CategoryController>();
    final homeCtrl = Get.find<HomeController>();
    final auth = Get.find<AuthService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.eco_outlined,
                color: cs.primaryContainer,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        actions: [
          Obx(() {
            final status = auth.status.value;
            final isFarmer = status == AuthStatus.farmerActive;
            final isAdmin = status == AuthStatus.admin;
            if (isFarmer && !auth.isBrowsingAsCustomer.value) {
              return TextButton.icon(
                onPressed: () => context.go('/farmer/dashboard'),
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Panelim'),
              );
            } else if (isFarmer && auth.isBrowsingAsCustomer.value) {
              return const SizedBox.shrink();
            } else if (isAdmin) {
              return TextButton.icon(
                onPressed: () => context.go('/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Admin'),
              );
            } else if (status == AuthStatus.customerActive) {
              return const SizedBox.shrink();
            } else {
              return TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_outlined, size: 18),
                label: const Text('Giriş'),
              );
            }
          }),
          const FarmerModeChip(),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.home),
      body: RefreshIndicator(
        onRefresh: () async {
          homeCtrl.load();
          catCtrl.load();
        },
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            const SliverToBoxAdapter(child: _HeroSearchBar()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // Categories
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Kategoriler',
                onSeeAll: () => context.push('/products/categories'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverToBoxAdapter(
              child: Obx(() {
                if (catCtrl.isLoading.value) {
                  return const _CategoryShimmer();
                }
                if (catCtrl.error.value != null) {
                  return SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        'Kategoriler yüklenemedi',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                }
                return _CategoryRow(categories: catCtrl.categories);
              }),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // New products
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Yeni Eklenenler',
                onSeeAll: () => context.push('/products'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverToBoxAdapter(
              child: Obx(() {
                if (homeCtrl.isLoading.value) {
                  return SizedBox(
                    height: productCardExtent(context, 168, compact: true),
                    child: const _HorizontalShimmer(),
                  );
                }
                if (homeCtrl.error.value != null) {
                  return const SizedBox(
                    height: 160,
                    child: AppEmptyWidget(message: 'Ürünler yüklenemedi'),
                  );
                }
                final items = homeCtrl.newProducts;
                if (items.isEmpty) {
                  return const SizedBox(
                    height: 160,
                    child: AppEmptyWidget(message: 'Henüz ürün bulunmuyor.'),
                  );
                }
                return SizedBox(
                  height: productCardExtent(context, 168, compact: true),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm + 4),
                    itemBuilder: (_, i) => SizedBox(
                      width: 168,
                      child: ProductCard(product: items[i], compact: true),
                    ),
                  ),
                );
              }),
            ),

            // Featured farmers
            SliverToBoxAdapter(
              child: Obx(() {
                final farmers = homeCtrl.featuredFarmers;
                if (farmers.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeader(title: 'Öne Çıkan Üreticiler'),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: farmerCardExtent(context),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: farmers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm + 4),
                        itemBuilder: (_, i) =>
                            FarmerCard(farmer: farmers[i], width: 172),
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            const SliverToBoxAdapter(child: _PlatformInfoCard()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(
              child: Obx(() {
                final isFarmer = auth.status.value == AuthStatus.farmerActive;
                return isFarmer ? const _FarmerPanelCtaCard() : const _GuestCtaCard();
              }),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

class _HeroSearchBar extends StatelessWidget {
  const _HeroSearchBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => context.push('/search'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md + 2,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: cs.onSurfaceVariant, size: 22),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      'Ürün veya üretici ara...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Tümünü Gör'),
            ),
        ],
      ),
    );
  }
}

IconData _iconForCategorySlug(String slug, String? backendIcon) {
  final s = slug.toLowerCase();
  if (s.contains('sebze') || s.contains('vegetable')) return Icons.eco_outlined;
  if (s.contains('meyve') || s.contains('fruit')) {
    return Icons.local_florist_outlined;
  }
  if (s.contains('yumurta') || s.contains('egg')) {
    return Icons.egg_alt_outlined;
  }
  if (s.contains('sut') || s.contains('süt') || s.contains('milk') || s.contains('dairy')) {
    return Icons.local_drink_outlined;
  }
  if (s.contains('bal') || s.contains('honey')) return Icons.hive_outlined;
  if (s.contains('tahil') || s.contains('tahıl') || s.contains('grain') || s.contains('bakliyat')) {
    return Icons.grass_outlined;
  }
  if (s.contains('et') || s.contains('meat')) {
    return Icons.restaurant_menu_outlined;
  }
  if (s.contains('zeytin') || s.contains('olive')) {
    return Icons.water_drop_outlined;
  }
  if (s.contains('peynir') || s.contains('cheese')) {
    return Icons.lunch_dining_outlined;
  }
  if (s.contains('bitki') || s.contains('herb') || s.contains('baharat')) {
    return Icons.spa_outlined;
  }
  return Icons.local_offer_outlined;
}

class _CategoryRow extends StatelessWidget {
  final List<CategoryModel> categories;
  const _CategoryRow({required this.categories});

  @override
  Widget build(BuildContext context) {
    final roots = categories.where((c) => c.isRoot).toList();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: roots.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final c = roots[i];
          return AppCategoryChip(
            label: c.name,
            icon: _iconForCategorySlug(c.slug, c.icon),
            onTap: () => context.push('/products?category_id=${c.id}'),
          );
        },
      ),
    );
  }
}

/// Pill-shaped shimmer chips that mimic the category row while loading.
class _CategoryShimmer extends StatelessWidget {
  const _CategoryShimmer();

  static const _widths = [88.0, 104.0, 76.0, 96.0, 82.0];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _widths.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => Shimmer.fromColors(
          baseColor: cs.surfaceContainerLow,
          highlightColor: cs.surfaceContainerHigh,
          child: Container(
            width: _widths[i],
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalShimmer extends StatelessWidget {
  const _HorizontalShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm + 4),
      itemBuilder: (_, __) => const SizedBox(
        width: 168,
        child: ShimmerProductCard(),
      ),
    );
  }
}

class _PlatformInfoCard extends StatelessWidget {
  const _PlatformInfoCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: cs.primaryContainer.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.handshake_outlined,
                color: cs.primaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aracısız. Komisyonsuz. Doğrudan üreticiden.',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.primaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.platformInfoText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCtaCard extends StatelessWidget {
  const _GuestCtaCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.agriculture_outlined,
                    color: cs.primaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Üretici misiniz?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Davet kodunuzla başvurun ve ürünlerinizi platformda yayınlayın.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Başvur',
                    onPressed: () => context.push('/apply'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login_outlined, size: 18),
                    label: const Text('Üretici Girişi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmerPanelCtaCard extends StatelessWidget {
  const _FarmerPanelCtaCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: cs.primaryContainer.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.dashboard_outlined, color: cs.primaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Çiftçi panelinize gitmek için tıklayın.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.primary,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/farmer/dashboard'),
              child: const Text('Panelim'),
            ),
          ],
        ),
      ),
    );
  }
}
