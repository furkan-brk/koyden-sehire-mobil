import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';

/// Landing screen shown at `/register`.
///
/// Lets the user pick between creating a customer account (instant,
/// phone+OTP+password+email) and starting the farmer application
/// flow (invite-based, /apply). Two clearly separated cards keep the
/// two paths from being confused.
class RegisterChoiceScreen extends StatelessWidget {
  const RegisterChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: null,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Icon(
                Icons.eco,
                size: 48,
                color: cs.primaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Hesap Oluştur',
              textAlign: TextAlign.center,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nasıl devam etmek istersiniz?',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _RoleCard(
              icon: Icons.shopping_basket_outlined,
              title: 'Müşteri olarak kayıt ol',
              subtitle:
                  'Ürünleri keşfedin, üreticileri takip edin. Telefon doğrulaması ile hemen başlayın.',
              cta: 'Müşteri Kaydı',
              onTap: () => context.push('/register/customer'),
            ),
            const SizedBox(height: AppSpacing.md),
            _RoleCard(
              icon: Icons.agriculture_outlined,
              title: 'Üretici olarak başvur',
              subtitle:
                  'Davet kodunuzla başvuru gönderin. Onay sonrası ürünlerinizi yayınlayabilirsiniz.',
              cta: 'Üretici Başvurusu',
              onTap: () => context.push('/apply'),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                child: const Text('Zaten hesabınız var mı? Giriş yapın'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: cs.primaryContainer, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: context.text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$cta →',
                        style: context.text.labelLarge?.copyWith(
                          color: cs.primaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
