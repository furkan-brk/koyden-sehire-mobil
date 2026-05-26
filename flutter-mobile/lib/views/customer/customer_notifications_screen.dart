import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/controllers/customer/customer_notifications_controller.dart';
import 'package:koyden_sehire/services/notification_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/notification_tile.dart';

class CustomerNotificationsScreen extends StatelessWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(
      CustomerNotificationsController(Get.find<NotificationRepository>()),
    );

    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final unread = ctrl.unreadCount.value;
          return Text(unread > 0 ? 'Bildirimlerim ($unread)' : 'Bildirimlerim');
        }),
        actions: [
          Obx(() {
            if (ctrl.items.any((n) => !n.isRead)) {
              return TextButton(
                onPressed: ctrl.markAllRead,
                child: const Text('Tümünü Okundu Say'),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      bottomNavigationBar: const CustomerBottomNav(current: CustomerTab.profile),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (ctrl.errorMessage.value != null) {
          return AppErrorWidget(
            message: ctrl.errorMessage.value!,
            onRetry: ctrl.load,
          );
        }
        if (ctrl.items.isEmpty) {
          return const NotificationEmptyState(role: 'customer');
        }
        return RefreshIndicator(
          onRefresh: ctrl.load,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: ctrl.items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 56, endIndent: 16),
            itemBuilder: (_, i) {
              final n = ctrl.items[i];
              return NotificationTile(
                notification: n,
                onTap: () => ctrl.markRead(n.id),
              );
            },
          ),
        );
      }),
    );
  }
}
