import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/farmer_mode_chip.dart';
import 'package:koyden_sehire/shared/widgets/product_card.dart';
import 'package:koyden_sehire/shared/widgets/public_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/shimmer_product_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final favs = Get.find<FavoritesService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorilerim'),
        leading: const FarmerModeChip(),
      ),
      bottomNavigationBar:
          const PublicBottomNav(current: PublicTab.applyOrFavorites),
      body: Obx(() {
        final isFarmerBrowsing = auth.status.value == AuthStatus.farmerActive &&
            auth.isBrowsingAsCustomer.value;
        if (auth.status.value != AuthStatus.customerActive && !isFarmerBrowsing) {
          return _GuestPlaceholder();
        }

        if (favs.isLoading.value && favs.items.isEmpty) {
          return const ShimmerList();
        }

        if (favs.errorMessage.value != null) {
          return AppErrorWidget(
            message: favs.errorMessage.value!,
            onRetry: favs.refresh,
          );
        }

        if (favs.items.isEmpty) {
          return AppEmptyWidget(
            icon: Icons.favorite_border,
            message: 'Henüz favori ürününüz yok',
            action: AppButton(
              label: 'Ürünleri Keşfet',
              fullWidth: false,
              onPressed: () => context.go('/products'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: favs.refresh,
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: favs.items.length,
            itemBuilder: (_, i) => ProductCard(product: favs.items[i]),
          ),
        );
      }),
    );
  }
}

class _GuestPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Favorileri görmek için giriş yapın',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Beğendiğiniz ürünleri kaydedin, her yerden erişin.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Giriş Yap',
              fullWidth: false,
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}
