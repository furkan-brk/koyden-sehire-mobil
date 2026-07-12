import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/onboarding_service.dart';
import 'package:koyden_sehire/core/services/push_notification_service.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const _pages = <_OnboardingPageData>[
  _OnboardingPageData(
    icon: Icons.eco_outlined,
    title: 'Köyden Şehire\'ye Hoş Geldiniz',
    body:
        'Yerel üreticilerin taze, doğal ve özenle hazırlanmış ürünlerini '
        'keşfedin. Sebzeden bala, süt ürünlerinden zeytinyağına — hepsi '
        'köyünden, üreticisinden.',
  ),
  _OnboardingPageData(
    icon: Icons.handshake_outlined,
    title: 'Aracısız ve Komisyonsuz',
    body: AppConstants.platformInfoText,
  ),
  _OnboardingPageData(
    icon: Icons.chat_bubble_outline,
    title: 'Üreticiyle Doğrudan İletişim',
    body:
        'Beğendiğiniz ürünün üreticisine WhatsApp veya telefonla doğrudan '
        'ulaşın. Yeni ürünler ve güncellemelerden haberdar olmak için '
        'bildirimlere izin verebilirsiniz.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Get.find<OnboardingService>().markSeen();
    if (mounted) context.go('/');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _allowNotifications() async {
    await Get.find<PushNotificationService>().requestPermissionNow();
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  right: AppSpacing.md,
                ),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Atla'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            _DotsIndicator(count: _pages.length, current: _page),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  if (_isLast) ...[
                    AppButton(
                      label: 'Bildirimlere İzin Ver',
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _allowNotifications,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Keşfetmeye Başla',
                      variant: AppButtonVariant.secondary,
                      onPressed: _finish,
                    ),
                  ] else
                    AppButton(
                      label: 'Devam',
                      onPressed: _next,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(data.icon, size: 56, color: cs.primaryContainer),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
