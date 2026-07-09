import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:koyden_sehire/shared/utils/responsive.dart';
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
import 'package:koyden_sehire/views/admin/widgets/admin_filter_bar.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({super.key});

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppBreakpoints.desktop;
        final hp = isDesktop ? 24.0 : 16.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hp, hp, hp, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ürün Moderasyonu',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Çiftçilerin oluşturduğu ürün ilanlarını kontrol edin ve yayına alın.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _ctrl.load,
                        icon: const Icon(Icons.refresh_outlined, size: 16),
                        label: const Text('Yenile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 16 : 12),
                  SearchField(
                    controller: _searchController,
                    hintText: 'Ürün, üretici veya kategori ara...',
                    onChanged: (v) => _ctrl.search.value = v,
                    onClear: () => _ctrl.search.value = '',
                  ),
                  const SizedBox(height: 12),
                  Obx(() => AdminChoiceChips(
                        selected: _ctrl.selectedStatus.value,
                        onSelected: (v) => _ctrl.selectedStatus.value = v,
                        options: const [
                          AdminFilterOption('all', 'Tümü'),
                          AdminFilterOption('pending', 'Onay Bekleyenler'),
                          AdminFilterOption('active', 'Yayındakiler'),
                          AdminFilterOption('rejected', 'Reddedilenler'),
                          AdminFilterOption('hidden', 'Yayından Kaldırılanlar'),
                        ],
                      )),
                  const SizedBox(height: 10),
                  Obx(() => Row(
                        children: [
                          Expanded(
                            child: AdminFilterDropdown(
                              icon: Icons.category_outlined,
                              hint: 'Tüm Kategoriler',
                              value: _ctrl.selectedCategoryId.value.isEmpty
                                  ? null
                                  : _ctrl.selectedCategoryId.value,
                              options: _ctrl.categoryOptions
                                  .map((e) =>
                                      AdminFilterOption(e.key, e.value))
                                  .toList(),
                              onChanged: (v) =>
                                  _ctrl.selectedCategoryId.value = v ?? '',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AdminFilterDropdown(
                              icon: Icons.location_on_outlined,
                              hint: 'Tüm Şehirler',
                              value: _ctrl.selectedCity.value.isEmpty
                                  ? null
                                  : _ctrl.selectedCity.value,
                              options: _ctrl.cityOptions
                                  .map((c) => AdminFilterOption(c, c))
                                  .toList(),
                              onChanged: (v) =>
                                  _ctrl.selectedCity.value = v ?? '',
                            ),
                          ),
                        ],
                      )),
                  SizedBox(height: isDesktop ? 16 : 8),
                ],
              ),
            ),
            if (isDesktop) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                color: AppColors.surfaceContainerLow,
                child: const Row(
                  children: [
                    SizedBox(width: 52),
                    SizedBox(width: 12),
                    Expanded(flex: 3, child: _ColLabel('ÜRÜN / ÜRETİCİ')),
                    Expanded(flex: 2, child: _ColLabel('KATEGORİ')),
                    Expanded(flex: 2, child: _ColLabel('FİYAT')),
                    SizedBox(width: 96, child: _ColLabel('DURUM')),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value) return const AppLoading();
                if (_ctrl.error.value.isNotEmpty) {
                  return AppErrorWidget(
                      message: _ctrl.error.value, onRetry: _ctrl.load);
                }
                final items = _ctrl.filteredItems;
                if (items.isEmpty) {
                  return const AppEmptyWidget(
                      message: 'Moderasyon bekleyen ürün bulunmuyor.');
                }
                if (isDesktop) {
                  return RefreshIndicator(
                    onRefresh: _ctrl.load,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final product = items[i];
                        final imageUrl = product.imageUrls.isNotEmpty
                            ? product.imageUrls.first
                            : null;
                        return InkWell(
                          onTap: () => context
                              .push('/admin/products/${product.id}'),
                          hoverColor: AppColors.surfaceContainerLow
                              .withValues(alpha: 0.6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                Container(
                                                    color: AppColors
                                                        .outlineVariant),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              color:
                                                  AppColors.outlineVariant,
                                              child: Icon(
                                                Icons.image_not_supported,
                                                size: 18,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: AppColors.outlineVariant,
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 18,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Product + Farmer
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product.farmer?.displayName ?? '—',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                // Category
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    product.category?.name ?? '—',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                // Price
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${product.price} ₺ / ${product.unit}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                // Status
                                SizedBox(
                                  width: 96,
                                  child: AdminStatusBadge(
                                      status: product.status),
                                ),
                                // Action
                                SizedBox(
                                  width: 48,
                                  child: Icon(Icons.chevron_right,
                                      color: cs.onSurfaceVariant, size: 20),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
                // Mobile
                return RefreshIndicator(
                  onRefresh: _ctrl.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
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
                                        child: Icon(
                                            Icons.image_not_supported,
                                            size: 20,
                                            color: cs.onSurfaceVariant),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.outlineVariant,
                                      child: Icon(
                                          Icons.image_not_supported,
                                          size: 20,
                                          color: cs.onSurfaceVariant),
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
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
                              ),
                              Text(
                                '${product.price} ₺ / ${product.unit}'
                                '${product.category != null ? ' · ${product.category!.name}' : ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
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
      },
    );
  }
}

class _ColLabel extends StatelessWidget {
  final String text;
  const _ColLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
