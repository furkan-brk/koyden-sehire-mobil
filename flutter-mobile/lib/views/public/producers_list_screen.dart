import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/farmer_card.dart';
import 'package:koyden_sehire/controllers/public/producers_list_controller.dart';
import 'package:koyden_sehire/services/farmer_repository.dart';

class ProducersListScreen extends StatefulWidget {
  const ProducersListScreen({super.key});

  @override
  State<ProducersListScreen> createState() => _ProducersListScreenState();
}

class _ProducersListScreenState extends State<ProducersListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final ProducersListController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(ProducersListController(Get.find<FarmerRepository>()));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    Get.delete<ProducersListController>();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _ctrl.loadMore();
    }
  }

  void _onSearchSubmitted(String value) =>
      _ctrl.applySearch(value.trim().isEmpty ? null : value.trim());

  void _showCitySheet() {
    final currentCity = _ctrl.city.value;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheet) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Şehre Göre Filtrele',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (currentCity != null)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _ctrl.applyCity(null);
                          },
                          child: const Text('Temizle'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'İl ara...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setSheet(() {}),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: AppConstants.turkishCities
                        .where((c) =>
                            searchCtrl.text.isEmpty ||
                            c.toLowerCase().contains(searchCtrl.text.toLowerCase()))
                        .map(
                          (city) => RadioListTile<String>(
                            title: Text(city),
                            value: city,
                            groupValue: currentCity,
                            onChanged: (v) {
                              Navigator.pop(ctx);
                              _ctrl.applyCity(v);
                            },
                            dense: true,
                            activeColor: AppColors.primary,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Üreticiler'),
      ),
      bottomNavigationBar:
          const CustomerBottomNav(current: CustomerTab.producers),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm + 4,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Üretici adı ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _ctrl.applySearch(null);
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              onChanged: (v) => setState(() {}),
              onSubmitted: _onSearchSubmitted,
              textInputAction: TextInputAction.search,
            ),
          ),
          Obx(() {
            final city = _ctrl.city.value;
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 4),
              child: Row(
                children: [
                  _CityChip(
                    city: city,
                    onTap: _showCitySheet,
                    onClear: city != null ? () => _ctrl.applyCity(null) : null,
                  ),
                ],
              ),
            );
          }),
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value && _ctrl.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_ctrl.errorMessage.value != null && _ctrl.items.isEmpty) {
                return AppErrorWidget(
                  message: _ctrl.errorMessage.value!,
                  onRetry: () => _ctrl.applySearch(_ctrl.search.value),
                );
              }
              if (_ctrl.items.isEmpty) {
                return const AppEmptyWidget(message: 'Üretici bulunamadı.');
              }
              return RefreshIndicator(
                onRefresh: () async {
                  await _ctrl.applySearch(_ctrl.search.value);
                },
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.sm + 4,
                    mainAxisSpacing: AppSpacing.sm + 4,
                    childAspectRatio: 172 / 220,
                  ),
                  itemCount: _ctrl.items.length +
                      (_ctrl.isLoadingMore.value ? 2 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _ctrl.items.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return FarmerCard(farmer: _ctrl.items[i]);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String? city;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _CityChip({
    required this.city,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = city != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryFixed : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive ? AppColors.primaryContainer : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 15,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              city ?? 'Şehir',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            if (isActive && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
