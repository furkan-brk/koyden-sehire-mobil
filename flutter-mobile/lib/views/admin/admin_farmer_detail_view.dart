import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/models/admin/admin_farmer_model.dart';
import 'package:koyden_sehire/services/admin_repository.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/controllers/admin/admin_farmer_detail_controller.dart';

class AdminFarmerDetailView extends StatefulWidget {
  final String farmerId;
  const AdminFarmerDetailView({super.key, required this.farmerId});

  @override
  State<AdminFarmerDetailView> createState() =>
      _AdminFarmerDetailViewState();
}

class _AdminFarmerDetailViewState extends State<AdminFarmerDetailView> {
  late final AdminFarmerDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = Get.find<AdminRepository>();
    _ctrl =
        Get.put(AdminFarmerDetailController(repo, widget.farmerId));
  }

  @override
  void dispose() {
    Get.delete<AdminFarmerDetailController>();
    super.dispose();
  }

  Color _trustColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  void _navigateToFarmer(String id) {
    context.go('/admin/farmers/$id');
  }

  void _showQuotaDialog(AdminFarmerDetail farmer) {
    final ctrl =
        TextEditingController(text: farmer.inviteQuota.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Davet Kotasını Düzenle'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Kota'),
        ),
        actions: [
          AppButton(
            label: 'İptal',
            variant: AppButtonVariant.text,
            fullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: 'Kaydet',
            variant: AppButtonVariant.primary,
            fullWidth: false,
            onPressed: () {
              final q = int.tryParse(ctrl.text);
              if (q != null) {
                _ctrl.updateQuota(q);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
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
          final farmer = _ctrl.farmer.value;
          if (farmer == null) return const SizedBox.shrink();

          if (isDesktop) return _buildDesktop(context, farmer);
          return _buildMobile(context, farmer);
        });
      },
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, AdminFarmerDetail farmer) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Breadcrumb header
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
                onTap: () => context.go('/admin/farmers'),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Üreticiler',
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
                child: Row(
                  children: [
                    Text(
                      farmer.fullName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (farmer.isFoundingFarmer) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 11, color: AppColors.secondary),
                            const SizedBox(width: 3),
                            Text('Kurucu',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Toggle status button
              Obx(() => OutlinedButton.icon(
                    onPressed: _ctrl.isActioning.value
                        ? null
                        : _ctrl.toggleStatus,
                    icon: _ctrl.isActioning.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            farmer.isActive
                                ? Icons.block
                                : Icons.check_circle_outline,
                            size: 15,
                            color: farmer.isActive
                                ? cs.error
                                : AppColors.success,
                          ),
                    label: Text(
                      farmer.isActive
                          ? 'Hesabı Askıya Al'
                          : 'Hesabı Aktifleştir',
                      style: TextStyle(
                        fontSize: 13,
                        color: farmer.isActive
                            ? cs.error
                            : AppColors.success,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: farmer.isActive
                              ? cs.error
                              : AppColors.success),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  )),
            ],
          ),
        ),
        // 2-column content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _ctrl.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: info + trust + referans kaynağı
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _InfoCard(farmer: farmer),
                        const SizedBox(height: 16),
                        _TrustCard(
                            farmer: farmer,
                            trustColor: _trustColor),
                        const SizedBox(height: 16),
                        _ReferredByCard(
                          farmer: farmer,
                          onNavigate: _navigateToFarmer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: invite + davet edilenler
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _InviteCard(
                          farmer: farmer,
                          onEditQuota: () => _showQuotaDialog(farmer),
                        ),
                        const SizedBox(height: 16),
                        _ReferralsCard(
                          farmer: farmer,
                          onNavigate: _navigateToFarmer,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile ──────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context, AdminFarmerDetail farmer) {
    return RefreshIndicator(
      onRefresh: _ctrl.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(farmer: farmer),
            const SizedBox(height: 12),
            _TrustCard(farmer: farmer, trustColor: _trustColor),
            const SizedBox(height: 12),
            _InviteCard(
              farmer: farmer,
              onEditQuota: () => _showQuotaDialog(farmer),
            ),
            const SizedBox(height: 12),
            _ReferredByCard(
              farmer: farmer,
              onNavigate: _navigateToFarmer,
            ),
            const SizedBox(height: 12),
            _ReferralsCard(
              farmer: farmer,
              onNavigate: _navigateToFarmer,
            ),
            const SizedBox(height: 16),
            Obx(() => AppButton(
                  label: farmer.isActive
                      ? 'Hesabı Askıya Al'
                      : 'Hesabı Aktifleştir',
                  variant: farmer.isActive
                      ? AppButtonVariant.destructive
                      : AppButtonVariant.primary,
                  isLoading: _ctrl.isActioning.value,
                  onPressed: _ctrl.isActioning.value
                      ? null
                      : _ctrl.toggleStatus,
                  icon: Icon(
                    farmer.isActive
                        ? Icons.block
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Shared cards ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final AdminFarmerDetail farmer;
  const _InfoCard({required this.farmer});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kişisel Bilgiler',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const Divider(height: 20),
            _Row(
                label: 'Ad Soyad',
                value: farmer.fullName),
            _Row(label: 'Telefon', value: farmer.phone),
            _Row(
                label: 'Şehir',
                value: '${farmer.city}, ${farmer.district}'),
            _Row(
              label: 'Durum',
              value: farmer.isActive ? 'Aktif' : 'Askıda',
              valueColor:
                  farmer.isActive ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  final AdminFarmerDetail farmer;
  final Color Function(double) trustColor;
  const _TrustCard(
      {required this.farmer, required this.trustColor});

  @override
  Widget build(BuildContext context) {
    final color = trustColor(farmer.trustScore);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Güven Skoru',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const Divider(height: 20),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    farmer.trustScore.toStringAsFixed(0),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _Metric(
                          label: 'Profil Tamamlama',
                          value:
                              '%${farmer.profileCompletion.toStringAsFixed(0)}'),
                      _Metric(
                          label: 'Video Doğrulama',
                          value:
                              farmer.hasVideoVerification ? 'Var' : 'Yok'),
                      _Metric(
                          label: 'Onaylı Ürünler',
                          value: farmer.approvedProducts.toString()),
                      _Metric(
                          label: 'Şikayetler',
                          value: farmer.complaints.toString()),
                      _Metric(
                          label: 'Davet Geçmişi',
                          value: farmer.inviteHistory.toString()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final AdminFarmerDetail farmer;
  final VoidCallback onEditQuota;
  const _InviteCard(
      {required this.farmer, required this.onEditQuota});

  @override
  Widget build(BuildContext context) {
    final quotaFraction = farmer.inviteQuota > 0
        ? farmer.usedInvites / farmer.inviteQuota
        : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Davet Bilgileri',
                    style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                IconButton(
                  onPressed: onEditQuota,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Kotayı Düzenle',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 20),
            if (farmer.inviteCode != null)
              _Row(label: 'Davet Kodu', value: farmer.inviteCode!),
            _Row(
                label: 'Kullanım',
                value:
                    '${farmer.usedInvites} / ${farmer.inviteQuota}'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: quotaFraction.clamp(0.0, 1.0),
                backgroundColor:
                    AppColors.outlineVariant.withValues(alpha: 0.4),
                color: AppColors.primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(quotaFraction * 100).toStringAsFixed(0)}% kullanıldı',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferredByCard extends StatelessWidget {
  final AdminFarmerDetail farmer;
  final void Function(String id) onNavigate;
  const _ReferredByCard({required this.farmer, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final refBy = farmer.referredBy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Referans Bilgisi',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Divider(height: 20),
            if (refBy == null)
              Text(
                'Bu üretici doğrudan veya referanssız kayıt olmuş.',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            else ...[
              _Row(label: 'Referans Olan', value: refBy.fullName),
              _Row(label: 'Telefon', value: refBy.phone),
              _Row(label: 'Şehir', value: refBy.city),
              if (farmer.inviteCode != null)
                _Row(label: 'Kullanılan Kod', value: farmer.inviteCode!),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => onNavigate(refBy.id),
                icon: const Icon(Icons.person_outline, size: 15),
                label: const Text('Referans Profiline Git',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralsCard extends StatelessWidget {
  final AdminFarmerDetail farmer;
  final void Function(String id) onNavigate;
  const _ReferralsCard({required this.farmer, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final referrals = farmer.referrals;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Davet Edilen Üreticiler',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Divider(height: 20),
            // Kota özeti
            if (farmer.inviteQuota > 0) ...[
              Row(
                children: [
                  Icon(Icons.people_outline,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Kota: ${farmer.usedInvites} / ${farmer.inviteQuota} kullanıldı',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (referrals.isEmpty)
              Text(
                'Bu üretici henüz kimseyi davet etmemiş.',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant),
              )
            else
              ...referrals.map((r) => _ReferralRow(
                    referral: r,
                    onTap: () => onNavigate(r.id),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  final FarmerReferral referral;
  final VoidCallback onTap;
  const _ReferralRow({required this.referral, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor =
        referral.isActive ? AppColors.success : AppColors.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    referral.displayName.isNotEmpty
                        ? referral.displayName
                        : referral.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  Text(
                    referral.city,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                referral.isActive ? 'Aktif' : 'Askıda',
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w500, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
