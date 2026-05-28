import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/admin/admin_application_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_risk_badge.dart';
import 'package:koyden_sehire/views/admin/widgets/admin_status_badge.dart';
import 'package:koyden_sehire/controllers/admin/admin_application_detail_controller.dart';
import 'package:koyden_sehire/core/utils/date_formatter.dart' show AppFormatters;

class AdminApplicationDetailView extends StatefulWidget {
  final String appId;
  const AdminApplicationDetailView({super.key, required this.appId});

  @override
  State<AdminApplicationDetailView> createState() =>
      _AdminApplicationDetailViewState();
}

class _AdminApplicationDetailViewState
    extends State<AdminApplicationDetailView> {
  late final AdminApplicationDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl = Get.put(
        AdminApplicationDetailController(repo, appId: widget.appId));
  }

  @override
  void dispose() {
    Get.delete<AdminApplicationDetailController>();
    super.dispose();
  }

  Future<void> _confirmReject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Başvuruyu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Lütfen reddetme sebebini yazın. Bu bilgi SMS ile üreticiye iletilecektir.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration:
                  const InputDecoration(hintText: 'Reddetme sebebi...'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'İptal',
            variant: AppButtonVariant.text,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: 'Reddet',
            variant: AppButtonVariant.destructive,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ).then((result) {
      reasonCtrl.dispose();
      return result;
    });
    if (confirmed == true && mounted) {
      final ok = await _ctrl.review('reject', reason: reasonCtrl.text);
      if (ok && mounted) context.snack('Başvuru reddedildi.');
    }
  }

  Future<void> _confirmApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Başvuruyu Onayla'),
        content: const Text('Bu başvuruyu onaylamak istiyor musunuz?'),
        actions: [
          AppButton(
            label: 'İptal',
            variant: AppButtonVariant.text,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: 'Onayla',
            variant: AppButtonVariant.primary,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await _ctrl.review('approve');
      if (ok && mounted) context.snack('Başvuru onaylandı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Obx(() {
          if (_ctrl.isLoading.value) return const AppLoading();
          if (_ctrl.error.value.isNotEmpty) {
            return AppErrorWidget(
                message: _ctrl.error.value, onRetry: _ctrl.load);
          }
          final app = _ctrl.application.value;
          if (app == null) return const SizedBox.shrink();

          if (isDesktop) return _buildDesktop(context, app);
          return _buildMobile(context, app);
        });
      },
    );
  }

  // ── Desktop ──────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, AdminApplication app) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Breadcrumb + actions
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => context.go('/admin/applications'),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Başvurular',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right,
                    size: 15, color: cs.outlineVariant),
              ),
              Expanded(
                child: Text(
                  app.fullName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              AdminStatusBadge(status: app.status),
              if (app.status == 'pending') ...[
                const SizedBox(width: 12),
                if (_ctrl.isSubmitting.value)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: _confirmReject,
                    icon: Icon(Icons.close, size: 15, color: cs.error),
                    label: Text('Reddet',
                        style: TextStyle(color: cs.error, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _confirmApprove,
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('Onayla',
                        style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        // 2-column content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _InfoCard(app: app)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _RiskCard(app: app),
                      if (app.adminNotes != null) ...[
                        const SizedBox(height: 16),
                        _AdminNotesCard(notes: app.adminNotes!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile ────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context, AdminApplication app) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(app.fullName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/applications'),
        ),
        actions: app.status == 'pending'
            ? [
                if (_ctrl.isSubmitting.value)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: _confirmReject,
                    icon: Icon(Icons.close, color: cs.error),
                    label:
                        Text('Reddet', style: TextStyle(color: cs.error)),
                  ),
                  TextButton.icon(
                    onPressed: _confirmApprove,
                    icon: Icon(Icons.check, color: cs.primary),
                    label:
                        Text('Onayla', style: TextStyle(color: cs.primary)),
                  ),
                ],
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoCard(app: app),
            const SizedBox(height: 16),
            _RiskCard(app: app),
            if (app.adminNotes != null) ...[
              const SizedBox(height: 16),
              _AdminNotesCard(notes: app.adminNotes!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared cards ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final AdminApplication app;
  const _InfoCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Üretici Bilgileri',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                AdminStatusBadge(status: app.status),
              ],
            ),
            const Divider(height: 20),
            _Field('Ad Soyad', app.fullName),
            _Field('İşletme Adı', app.businessName),
            _Field('Telefon', app.phone),
            _Field(
                'Lokasyon',
                '${app.city}, ${app.district}'
                    '${app.village != null ? ' - ${app.village}' : ''}'),
            _Field('Başvuru Tarihi', AppFormatters.date(app.createdAt)),
            if (app.profileDescription != null)
              _Field('Hakkında', app.profileDescription!),
            if (app.productExamples != null)
              _Field('Ürün Örnekleri', app.productExamples!),
          ],
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final AdminApplication app;
  const _RiskCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk Analizi',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const Divider(height: 20),
            if (app.riskLevel != null)
              _RiskRow('Genel Risk', AdminRiskBadge(level: app.riskLevel!)),
            if (app.inviteCode != null)
              _StrRow(
                  'Davet Kodu',
                  '${app.inviteCode}'
                      '${app.inviteTrust != null ? ' (${app.inviteTrust})' : ''}'),
            _VideoRow(videoUrl: app.videoUrl),
          ],
        ),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final String? videoUrl;
  const _VideoRow({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Video Durumu', style: TextStyle(fontSize: 13)),
          if (videoUrl != null)
            const Row(
              children: [
                Icon(Icons.videocam_outlined,
                    size: 14, color: AppColors.success),
                SizedBox(width: 4),
                Text('Yüklendi',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500)),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.videocam_off_outlined,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('Eksik',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }
}

class _AdminNotesCard extends StatelessWidget {
  final String notes;
  const _AdminNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Notları',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const Divider(height: 20),
            Text(notes, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final String label;
  final Widget badge;
  const _RiskRow(this.label, this.badge);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          badge,
        ],
      ),
    );
  }
}

class _StrRow extends StatelessWidget {
  final String label;
  final String value;
  const _StrRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
