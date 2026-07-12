import 'package:flutter/material.dart';
import 'package:koyden_sehire/shared/utils/responsive.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:koyden_sehire/app/constants.dart';
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

// ── Label maps ──────────────────────────────────────────────────────────────

const _producerTypeLabels = {
  'individual_farmer': 'Bireysel Çiftçi',
  'family_producer': 'Aile Üreticisi',
  'cooperative': 'Kooperatif',
  'small_producer': 'Küçük Üretici',
  'dairy_producer': 'Süt Üreticisi',
  'beekeeper': 'Arıcı',
  'olive_producer': 'Zeytin Üreticisi',
  'other': 'Diğer',
};

const _productionPlaceLabels = {
  'own_land': 'Kendi Arazisi',
  'family_land': 'Aile Arazisi',
  'rented_land': 'Kiralık Arazi',
  'cooperative_production': 'Kooperatif Üretimi',
  'home_production': 'Ev Üretimi',
  'other': 'Diğer',
};

// ── Main view ────────────────────────────────────────────────────────────────

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
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (confirmed == true && mounted) {
      final ok = await _ctrl.review('reject', reason: reason);
      if (ok && mounted) {
        context.snack('Başvuru reddedildi.');
      }
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
        final isDesktop = constraints.maxWidth >= AppBreakpoints.desktop;
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _PersonalCard(app: app),
                      const SizedBox(height: 14),
                      _BusinessCard(app: app),
                      const SizedBox(height: 14),
                      _ProductionCard(app: app),
                      const SizedBox(height: 14),
                      _MediaCard(app: app),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _SummaryCard(app: app),
                      const SizedBox(height: 14),
                      _LocationCard(app: app),
                      const SizedBox(height: 14),
                      _DeclarationsCard(app: app),
                      if (app.adminNote != null) ...[
                        const SizedBox(height: 14),
                        _AdminNoteCard(note: app.adminNote!),
                      ],
                      if (app.rejectionReason != null) ...[
                        const SizedBox(height: 14),
                        _RejectionCard(reason: app.rejectionReason!),
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
                    label: Text('Reddet', style: TextStyle(color: cs.error)),
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
            _SummaryCard(app: app),
            const SizedBox(height: 12),
            _PersonalCard(app: app),
            const SizedBox(height: 12),
            _BusinessCard(app: app),
            const SizedBox(height: 12),
            _LocationCard(app: app),
            const SizedBox(height: 12),
            _ProductionCard(app: app),
            const SizedBox(height: 12),
            _MediaCard(app: app),
            const SizedBox(height: 12),
            _DeclarationsCard(app: app),
            if (app.adminNote != null) ...[
              const SizedBox(height: 12),
              _AdminNoteCard(note: app.adminNote!),
            ],
            if (app.rejectionReason != null) ...[
              const SizedBox(height: 12),
              _RejectionCard(reason: app.rejectionReason!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section cards ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final AdminApplication app;
  const _SummaryCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Başvuru Özeti',
      icon: Icons.assignment_outlined,
      children: [
        _FieldRow('Durum', child: AdminStatusBadge(status: app.status)),
        if (app.riskLevel != null)
          _FieldRow('Risk', child: AdminRiskBadge(level: app.riskLevel!)),
        _Field('Başvuru Tarihi', AppFormatters.dateTime(app.createdAt)),
        if (app.reviewedAt != null)
          _Field(
            app.status == 'rejected'
                ? 'Reddedilme Tarihi'
                : 'Onaylanma Tarihi',
            AppFormatters.dateTime(app.reviewedAt!),
          ),
        if (app.inviteCode != null)
          _Field('Davet Kodu',
              '${app.inviteCode}${app.inviteTrust != null ? ' (${app.inviteTrust})' : ''}'),
      ],
    );
  }
}

class _PersonalCard extends StatelessWidget {
  final AdminApplication app;
  const _PersonalCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Kişisel ve İletişim Bilgileri',
      icon: Icons.person_outline,
      children: [
        _FieldWrap([
          _Field('Ad Soyad', app.fullName),
          _Field('Telefon', app.phone),
          _Field('E-posta', app.email ?? 'Belirtilmemiş'),
        ]),
      ],
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final AdminApplication app;
  const _BusinessCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'İşletme ve Üretici Bilgileri',
      icon: Icons.store_outlined,
      children: [
        _FieldWrap([
          _Field('İşletme / Çiftlik Adı',
              app.businessName.isEmpty ? 'Belirtilmemiş' : app.businessName),
          _Field('Üretici Tipi',
              _producerTypeLabels[app.producerType] ?? app.producerType),
        ]),
        _Field('Biyografi / Hakkında',
            (app.bio == null || app.bio!.isEmpty) ? 'Belirtilmemiş' : app.bio!),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final AdminApplication app;
  const _LocationCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Konum Bilgileri',
      icon: Icons.location_on_outlined,
      children: [
        _Field('İl', app.city.isEmpty ? 'Belirtilmemiş' : app.city),
        _Field('İlçe', app.district.isEmpty ? 'Belirtilmemiş' : app.district),
        _Field('Köy / Mahalle',
            (app.village == null || app.village!.isEmpty)
                ? 'Belirtilmemiş'
                : app.village!),
      ],
    );
  }
}

class _ProductionCard extends StatelessWidget {
  final AdminApplication app;
  const _ProductionCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ürün ve Üretim Bilgileri',
      icon: Icons.eco_outlined,
      children: [
        if (app.productCategories.isNotEmpty)
          _FieldRow(
            'Ürün Kategorileri',
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: app.productCategories
                  .map((c) => _Chip(label: c))
                  .toList(),
            ),
          )
        else
          const _Field('Ürün Kategorileri', 'Belirtilmemiş'),
        _FieldWrap([
          _Field(
            'Üretim Yeri',
            app.productionPlaceType == null
                ? 'Belirtilmemiş'
                : (_productionPlaceLabels[app.productionPlaceType!] ??
                    app.productionPlaceType!),
          ),
          _Field('Ürün Örnekleri',
              (app.productExamples == null || app.productExamples!.isEmpty)
                  ? 'Belirtilmemiş'
                  : app.productExamples!),
        ]),
        _Field('Başvuru Notu',
            (app.applicationNote == null || app.applicationNote!.isEmpty)
                ? 'Belirtilmemiş'
                : app.applicationNote!),
      ],
    );
  }
}

class _MediaCard extends StatelessWidget {
  final AdminApplication app;
  const _MediaCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Belgeler ve Video',
      icon: Icons.attach_file_outlined,
      children: [
        // Video
        const _Label('Tanıtım Videosu'),
        const SizedBox(height: 6),
        if (app.applicationVideoUrl != null)
          _LinkTile(
            label: 'Videoyu Aç',
            icon: Icons.videocam_outlined,
            url: app.applicationVideoUrl!,
          )
        else
          const _EmptyText('Video yüklenmemiş'),
        const SizedBox(height: 12),
        // Documents
        const _Label('Belgeler'),
        const SizedBox(height: 6),
        if (app.documentUrls.isNotEmpty)
          ...app.documentUrls.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _LinkTile(
                    label: 'Belge ${e.key + 1}',
                    icon: Icons.insert_drive_file_outlined,
                    url: e.value,
                  ),
                ),
              )
        else
          const _EmptyText('Belge yüklenmemiş'),
      ],
    );
  }
}

class _DeclarationsCard extends StatelessWidget {
  final AdminApplication app;
  const _DeclarationsCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Yasal Onaylar ve Beyanlar',
      icon: Icons.verified_outlined,
      children: [
        _DeclarationRow('KVKK Onayı', app.kvkkAccepted),
        _DeclarationRow('Kullanıcı Sözleşmesi', app.platformTermsAccepted),
        _DeclarationRow(
            'Kendi üretimini sattığını beyan etti', app.declaresOwnProduction),
        _DeclarationRow(
            'Konum bilgilerinin doğru olduğunu beyan etti',
            app.declaresAccurateLocation),
        _DeclarationRow(
            'Aracı/komisyoncu olmadığını beyan etti',
            app.declaresNotIntermediary),
      ],
    );
  }
}

class _AdminNoteCard extends StatelessWidget {
  final String note;
  const _AdminNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Admin Notu',
      icon: Icons.edit_note_outlined,
      children: [
        Text(note, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _RejectionCard extends StatelessWidget {
  final String reason;
  const _RejectionCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Red Gerekçesi',
      icon: Icons.cancel_outlined,
      iconColor: AppColors.error,
      children: [
        Text(reason,
            style: const TextStyle(fontSize: 13, color: AppColors.error)),
      ],
    );
  }
}

// ── Reusable primitives ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 16, color: iconColor ?? AppColors.primaryContainer),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Lays out its [children] two-per-row (each half width) on wide enough space,
/// falling back to a single stacked column when a half column would be too
/// narrow (protects the mobile view).
class _FieldWrap extends StatelessWidget {
  final List<Widget> children;
  const _FieldWrap(this.children);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final half = (constraints.maxWidth - gap) / 2;
        final itemWidth = half < 140 ? constraints.maxWidth : half;
        return Wrap(
          spacing: gap,
          runSpacing: 0,
          children: children
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldRow(this.label, {required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3));
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, color: AppColors.onSurfaceVariant));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: AppColors.primaryContainer.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String url;
  const _LinkTile(
      {required this.label, required this.icon, required this.url});

  Future<void> _open() async {
    // Dev'de backend localhost/minio host'lu URL döndürebilir — bunları
    // uygulamanın konuştuğu host'a çevirir (bkz. AppConstants.formatDevUrl).
    final uri = Uri.tryParse(AppConstants.formatDevUrl(url));
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.open_in_new,
                size: 14, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DeclarationRow extends StatelessWidget {
  final String label;
  final bool accepted;
  const _DeclarationRow(this.label, this.accepted);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.check_circle : Icons.cancel,
            size: 17,
            color: accepted ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13)),
          ),
          Text(
            accepted ? 'Onaylandı' : 'Onaylanmadı',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accepted ? AppColors.success : AppColors.error),
          ),
        ],
      ),
    );
  }
}
