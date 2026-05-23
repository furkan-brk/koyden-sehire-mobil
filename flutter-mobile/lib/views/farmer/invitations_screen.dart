import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/models/invitation_model.dart';
import 'package:koyden_sehire/controllers/farmer/invitation_controller.dart';

class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<InvitationController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Davetlerim')),
      bottomNavigationBar: const FarmerBottomNav(current: FarmerTab.invites),
      body: Obx(() {
        if (ctrl.isLoading.value) return const AppLoading();
        if (ctrl.error.value != null) {
          return AppErrorWidget(
            message: ctrl.error.value!,
            onRetry: ctrl.load,
          );
        }
        final codes = ctrl.items;
        if (codes.isEmpty) {
          return const AppEmptyWidget(
            message: 'Henüz aktif davet kodunuz yok.',
            icon: Icons.card_giftcard_outlined,
          );
        }
        return RefreshIndicator(
          onRefresh: ctrl.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: codes.expand((c) => [
                  _InviteCard(item: c),
                  const SizedBox(height: 16),
                  if (c.invited.isNotEmpty) _InvitedList(invited: c.invited),
                  if (c.invited.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Henüz davet ettiğiniz kimse yok.',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 24),
                ]).toList(),
          ),
        );
      }),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final InviteCodeItem item;
  const _InviteCard({required this.item});

  String get _shareLink => 'https://koydensehre.com/apply?invite=${item.code}';
  String get _shareMessage =>
      "Merhaba, seni Köyden Şehre üretici ağına davet ediyorum. "
      "Başvuru için: $_shareLink";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Davet Kodunuz',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            item.code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 32,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${item.remaining} davet hakkınız kaldı (toplam ${item.maxUses})',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Kodu Kopyala',
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: item.code));
                    if (context.mounted) {
                      context.toast('Davet kodu kopyalandı');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Paylaş',
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => Share.share(_shareMessage),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitedList extends StatelessWidget {
  final List<InvitedPerson> invited;
  const _InvitedList({required this.invited});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Davet Ettikleriniz',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...invited.map((p) {
          final (label, color) = switch (p.status) {
            'approved' => ('Onaylandı', AppColors.success),
            'rejected' => ('Reddedildi', AppColors.error),
            _ => ('Beklemede', AppColors.warning),
          };
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name ?? 'Bekleyen Başvuru',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (p.createdAt != null)
                        Text(
                          AppFormatters.date(p.createdAt!),
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
