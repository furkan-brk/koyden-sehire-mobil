// TODO: Favorites API hazır olduğunda burada gerçek favori listesi gösterilecek.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';

class CustomerFavoritesScreen extends StatelessWidget {
  const CustomerFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Henüz favori ilanınız yok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Beğendiğiniz ürünleri favorilerinize eklediğinizde burada görebileceksiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 220,
                  child: AppButton(
                    label: 'Ürünleri Keşfet',
                    onPressed: () => context.go('/products'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
