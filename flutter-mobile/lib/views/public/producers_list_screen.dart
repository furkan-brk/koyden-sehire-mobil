import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                hintText: 'Üretici adı, şehir ara...',
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
                onRefresh: () => _ctrl.applySearch(_ctrl.search.value),
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
