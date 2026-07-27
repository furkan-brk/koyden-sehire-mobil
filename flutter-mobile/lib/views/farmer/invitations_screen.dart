import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart';
import 'package:koyden_sehire/core/utils/share_helper.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_empty_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/farmer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/status_badge.dart';
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

  String get _shareLink => AppConstants.inviteLink(item.code);
  String get _shareMessage =>
      "Merhaba, seni Köyden Şehre üretici ağına davet ediyorum.\n"
      "Davet kodun: ${item.code}\n"
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
                  onDark: true,
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
                  onPressed: () => ShareHelper.shareText(context, _shareMessage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.qr_code, size: 18),
              label: const Text('QR Göster'),
              onPressed: () => _showQrSheet(
                context,
                code: item.code,
                link: _shareLink,
                shareMessage: _shareMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showQrSheet(
  BuildContext context, {
  required String code,
  required String link,
  required String shareMessage,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
    ),
    builder: (ctx) => _InviteQrSheet(
      code: code,
      link: link,
      shareMessage: shareMessage,
    ),
  );
}

class _InviteQrSheet extends StatelessWidget {
  final String code;
  final String link;
  final String shareMessage;

  const _InviteQrSheet({
    required this.code,
    required this.link,
    required this.shareMessage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Davet Bağlantısı',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Davet etmek istediğiniz kişi bu QR kodu tarayarak başvuru sayfasına gidebilir.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: QrImageView(
                data: link,
                size: 220,
                backgroundColor: Colors.white,
                version: QrVersions.auto,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              link,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Paylaş',
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => ShareHelper.shareText(context, shareMessage),
              ),
            ),
          ],
        ),
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
          final badgeKind = switch (p.status) {
            'approved' => StatusKind.active,
            'rejected' => StatusKind.rejected,
            _ => StatusKind.pending,
          };
          final badgeLabel = switch (p.status) {
            'approved' => 'Onaylandı',
            'rejected' => 'Reddedildi',
            _ => 'Beklemede',
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
                StatusBadge(kind: badgeKind, label: badgeLabel),
              ],
            ),
          );
        }),
      ],
    );
  }
}
