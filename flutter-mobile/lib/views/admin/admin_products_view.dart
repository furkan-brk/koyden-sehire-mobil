import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_status_badge.dart';
import 'package:koyden_sehire/controllers/admin/admin_products_controller.dart';
import 'package:koyden_sehire/shared/widgets/search_field.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({super.key});

  @override
  State<AdminProductsView> createState() =>
      _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> {
  late final AdminProductsController _ctrl;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(AdminProductsController(repo));
  }

  @override
  void dispose() {
    Get.delete<AdminProductsController>();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ürün Moderasyonu',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Sisteme eklenen ürünlerin incelenmesi ve onaylanması.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SearchField(
                controller: _searchController,
                hintText: 'Ürün, üretici veya kategori ara...',
                onChanged: (v) => _ctrl.search.value = v,
                onClear: () => _ctrl.search.value = '',
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (_ctrl.isLoading.value) {
              return const AppLoading();
            }
            if (_ctrl.error.value.isNotEmpty) {
              return AppErrorWidget(
                message: _ctrl.error.value,
                onRetry: _ctrl.load,
              );
            }
            final items = _ctrl.filteredItems;
            if (items.isEmpty) {
              return const AppEmptyWidget(message: 'Henüz ürün bulunmuyor.');
            }
            return RefreshIndicator(
              onRefresh: _ctrl.load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final product = items[i];
                  final imageUrl = product.imageUrls.isNotEmpty
                      ? product.imageUrls.first
                      : null;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      color: AppColors.outlineVariant),
                                  errorWidget: (_, __, ___) => Container(
                                      color: AppColors.outlineVariant,
                                      child: Icon(Icons.image_not_supported,
                                          size: 20, color: cs.onSurfaceVariant)),
                                )
                              : Container(
                                  color: AppColors.outlineVariant,
                                  child: Icon(Icons.image_not_supported,
                                      size: 20, color: cs.onSurfaceVariant),
                                ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          AdminStatusBadge(status: product.status),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(
                            product.farmer?.displayName ?? '—',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          Text(
                            '${product.price} ₺ / ${product.unit}'
                            '${product.category != null ? ' · ${product.category!.name}' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/admin/products/${product.id}'),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}
