import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/favorites_service.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/product_card.dart';
import 'package:koyden_sehire/shared/widgets/shimmer_product_card.dart';

class CustomerFavoritesScreen extends StatelessWidget {
  const CustomerFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favs = Get.find<FavoritesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: Obx(() {
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
