import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/controllers/customer/customer_profile_controller.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/utils/validators.dart' show Validators;
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await auth.logout();
    if (context.mounted) context.go('/');
  }

  void _showEditSheet(BuildContext context, CustomerProfileController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditSheet(ctrl: ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final ctrl = Get.find<CustomerProfileController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Geri',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          Obx(() {
            if (ctrl.isLoading.value || ctrl.profile.value == null) {
              return const SizedBox.shrink();
            }
            return TextButton.icon(
              onPressed: () => _showEditSheet(context, ctrl),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Düzenle'),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) return const AppLoading();

        if (ctrl.errorMessage.value != null && ctrl.profile.value == null) {
          return AppErrorWidget(
            message: ctrl.errorMessage.value!,
            onRetry: ctrl.load,
          );
        }

        final profile = ctrl.profile.value;
        if (profile == null) return const AppLoading();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _ProfileHeaderCard(name: profile.fullName),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Hesap Bilgileri',
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Ad Soyad',
                  value: profile.fullName,
                ),
                const _Divider(),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Telefon',
                  value: profile.phone,
                ),
                const _Divider(),
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'E-posta',
                  value: profile.email?.isNotEmpty == true
                      ? profile.email!
                      : 'Belirtilmemiş',
                  muted: profile.email == null || profile.email!.isEmpty,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Müşteri Alanı',
              children: [
                _NavRow(
                  icon: Icons.favorite_border,
                  iconColor: AppColors.error,
                  label: 'Favorilerim',
                  subtitle: 'Kaydettiğin ürünleri burada görebilirsin.',
                  onTap: () => context.push('/favorites'),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.primaryContainer,
                  label: 'Bildirimlerim',
                  subtitle:
                      'Uygulama duyurularını ve ürün haberlerini buradan takip edebilirsin.',
                  onTap: () => context.push('/customer/notifications'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Köyden Şehre Nasıl Çalışır?',
              titleIcon: Icons.info_outline,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    "Köyden Şehre'de ödeme, sepet, sipariş, kargo veya uygulama içi mesajlaşma bulunmaz. Müşteri, üreticiyle doğrudan iletişime geçer.",
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Hesap İşlemleri',
              children: [
                _DangerRow(
                  icon: Icons.logout,
                  label: 'Çıkış Yap',
                  isLast: true,
                  onTap: () => _confirmLogout(context, auth),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }
}

class _EditSheet extends StatefulWidget {
  final CustomerProfileController ctrl;
  const _EditSheet({required this.ctrl});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final p = widget.ctrl.profile.value;
    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim();
    final ok = await widget.ctrl.update(
      fullName: _nameCtrl.text.trim(),
      email: email.isEmpty ? null : email,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      Get.snackbar(
        'Kaydedildi',
        'Profiliniz güncellendi',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profili Düzenle',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _nameCtrl,
              label: 'Ad Soyad',
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'En az 2 karakter giriniz';
                }
                if (v.trim().length > 100) return 'En fazla 100 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _emailCtrl,
              label: 'E-posta (isteğe bağlı)',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return Validators.email(v.trim());
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Telefon numarası değiştirilemez.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Obx(() => AppButton(
                  label: 'Kaydet',
                  isLoading: widget.ctrl.isSaving.value,
                  onPressed: _save,
                )),
            Obx(() {
              final err = widget.ctrl.errorMessage.value;
              if (err == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  err,
                  style: const TextStyle(color: AppColors.error),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  const _ProfileHeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.primaryContainer.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.secondaryContainer,
            child: Icon(Icons.person, size: 36, color: cs.primaryContainer),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Müşteri Hesabı',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.secondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ürünleri keşfet, favorilerini takip et ve üreticilerle doğrudan iletişime geç.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.titleIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          ...children,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, indent: 16);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: muted
                        ? AppColors.onSurfaceVariant
                        : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  const _DangerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(AppRadius.md))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.error),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
