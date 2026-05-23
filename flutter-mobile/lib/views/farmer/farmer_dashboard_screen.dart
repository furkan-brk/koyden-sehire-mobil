import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/models/farmer_product_model.dart';
import 'package:koyden_sehire/controllers/farmer/farmer_profile_controller.dart';
import 'package:koyden_sehire/models/dashboard_model.dart';
import 'package:koyden_sehire/controllers/farmer/dashboard_controller.dart';

class FarmerDashboardScreen extends StatelessWidget {
  const FarmerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashCtrl = Get.find<DashboardController>();
    final profileCtrl = Get.find<FarmerProfileController>();
    final auth = Get.find<AuthService>();

    return Scaffold(
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.dashboard),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        title: Obx(() {
          final displayName = profileCtrl.profile.value?.displayName ??
              auth.displayName.value ??
              'Üretici';
          final cs = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Merhaba, $displayName'),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 11, color: cs.primaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Markete Gözat',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.primaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
        actions: [
          Obx(() {
            final profile = profileCtrl.profile.value;
            return IconButton(
              icon: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceContainerLow,
                backgroundImage: profile?.profileImageUrl == null
                    ? null
                    : CachedNetworkImageProvider(profile!.profileImageUrl!),
                child: profile?.profileImageUrl == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              onPressed: () => context.push('/farmer/profile'),
            );
          }),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Obx(() {
        if (dashCtrl.isLoading.value && dashCtrl.data.value == null) {
          return const AppLoading();
        }
        if (dashCtrl.error.value != null && dashCtrl.data.value == null) {
          return AppErrorWidget(
            message: dashCtrl.error.value!,
            onRetry: dashCtrl.load,
          );
        }
        final data = dashCtrl.data.value;
        if (data == null) return const AppLoading();
        return RefreshIndicator(
          onRefresh: dashCtrl.load,
          child: _Body(data: data),
        );
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final DashboardData data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            _StatCard(
              label: 'Aktif Ürünler',
              value: data.activeCount,
              color: AppColors.success,
              icon: Icons.check_circle_outline,
            ),
            _StatCard(
              label: 'Bekleyen',
              value: data.pendingCount,
              color: AppColors.warning,
              icon: Icons.hourglass_bottom,
            ),
            _StatCard(
              label: 'Pasif',
              value: data.hiddenCount,
              color: AppColors.onSurfaceVariant,
              icon: Icons.visibility_off_outlined,
            ),
            _StatCard(
              label: 'Davet Hakkı',
              value: data.inviteRemaining,
              color: AppColors.primary,
              icon: Icons.card_giftcard_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _QuickActions(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Son Ürünlerim',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/farmer/products'),
              child: const Text('Tümünü Gör'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (data.recentProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Henüz ürün eklemediniz.',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          )
        else
          ...data.recentProducts.map((p) => _RecentProductTile(product: p)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'Yeni Ürün Ekle',
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () => context.push('/farmer/products/new'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Profil',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push('/farmer/profile'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Davetler',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push('/farmer/invites'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentProductTile extends StatelessWidget {
  final FarmerProductModel product;
  const _RecentProductTile({required this.product});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.push('/farmer/products/${product.id}/edit'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: product.imageUrls.isEmpty
                    ? Container(
                        color: AppColors.surfaceContainerLow,
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.onSurfaceVariant),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.imageUrls.first,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: AppColors.surfaceContainerLow),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(AppFormatters.price(product.price, product.unit),
                      style: const TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
            _StatusBadge(status: product.status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Aktif', AppColors.success),
      'pending' => ('Beklemede', AppColors.warning),
      'rejected' => ('Reddedildi', AppColors.error),
      'hidden' => ('Pasif', AppColors.onSurfaceVariant),
      _ => (status, AppColors.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
