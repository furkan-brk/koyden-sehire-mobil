import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/controllers/farmer/farmer_notifications_controller.dart';
import 'package:koyden_sehire/models/notification_model.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/notification_tile.dart';
import 'package:koyden_sehire/shared/widgets/shimmer_notification_tile.dart';

class FarmerNotificationsScreen extends StatefulWidget {
  const FarmerNotificationsScreen({super.key});

  @override
  State<FarmerNotificationsScreen> createState() =>
      _FarmerNotificationsScreenState();
}

class _FarmerNotificationsScreenState extends State<FarmerNotificationsScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  FarmerNotificationsController get _ctrl =>
      Get.find<FarmerNotificationsController>();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadMore();
    }
  }

  void _handleTap(AppNotification n) {
    _ctrl.markRead(n.id);
    final productId = n.data['product_id']?.toString();
    if (productId != null && productId.isNotEmpty) {
      context.push('/products/$productId');
      return;
    }
    final farmerId = n.data['farmer_id']?.toString();
    if (farmerId != null && farmerId.isNotEmpty) {
      context.push('/farmers/$farmerId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final unread = _ctrl.unreadCount.value;
          return Text(unread > 0 ? 'Bildirimlerim ($unread)' : 'Bildirimlerim');
        }),
        actions: [
          Obx(() {
            if (_ctrl.items.any((n) => !n.isRead)) {
              return TextButton(
                onPressed: _ctrl.markAllRead,
                child: const Text('Tümünü Okundu Say'),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _ctrl.load,
        child: Obx(() {
          if (_ctrl.isLoading.value && _ctrl.items.isEmpty) {
            return const ShimmerNotificationList(count: 6);
          }
          if (_ctrl.errorMessage.value != null && _ctrl.items.isEmpty) {
            return LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Center(
                    child: AppErrorWidget(
                      message: _ctrl.errorMessage.value!,
                      onRetry: _ctrl.load,
                    ),
                  ),
                ),
              ),
            );
          }
          if (_ctrl.items.isEmpty) {
            return LayoutBuilder(
              builder: (ctx, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: const Center(
                    child: NotificationEmptyState(role: 'farmer'),
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _ctrl.items.length + 1,
            separatorBuilder: (_, i) {
              if (i >= _ctrl.items.length - 1) return const SizedBox.shrink();
              return const Divider(height: 1, indent: 56, endIndent: 16);
            },
            itemBuilder: (_, i) {
              if (i >= _ctrl.items.length) {
                if (_ctrl.isLoadingMore.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              final n = _ctrl.items[i];
              return NotificationTile(
                notification: n,
                onTap: () => _handleTap(n),
              );
            },
          );
        }),
      ),
    );
  }
}
