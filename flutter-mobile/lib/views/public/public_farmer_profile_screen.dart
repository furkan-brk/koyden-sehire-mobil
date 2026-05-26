import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/recent_views_service.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';
import 'package:koyden_sehire/core/utils/whatsapp_helper.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/farmer_mode_chip.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_error_widget.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/shared/widgets/customer_bottom_nav.dart';
import 'package:koyden_sehire/shared/widgets/founding_badge.dart';
import 'package:koyden_sehire/shared/widgets/product_card.dart';
import 'package:koyden_sehire/shared/widgets/verified_badge.dart';
import 'package:koyden_sehire/services/farmer_repository.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/controllers/public/farmer_controller.dart';

class FarmerProfileScreen extends StatefulWidget {
  final String farmerId;
  const FarmerProfileScreen({super.key, required this.farmerId});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  bool _phoneRevealed = false;
  late final FarmerController _ctrl;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      FarmerController(
        Get.find<FarmerRepository>(),
        farmerId: widget.farmerId,
      ),
      tag: widget.farmerId,
    );
    ever<FarmerProfile?>(_ctrl.profile, (p) {
      if (p != null) {
        Get.find<RecentViewsService>().addFarmer(
          id: p.id,
          title: p.displayName,
          imageUrl: p.profileImageUrl,
        );
      }
    });
  }

  @override
  void dispose() {
    Get.delete<FarmerController>(tag: widget.farmerId);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) context.toast('Telefon panoya kopyalandı');
    }
  }

  Future<void> _copy(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) context.toast('Telefon panoya kopyalandı');
  }

  Future<void> _openWhatsApp(String? phone) async {
    const message =
        'Merhaba, Köyden Şehre üzerinden profilinizi gördüm. '
        'Ürünleriniz hakkında bilgi almak istiyorum.';
    final ok = await WhatsAppHelper.open(phone, message);
    if (!ok && mounted) {
      context.toast('Bu üretici için iletişim bilgisi bulunamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Obx(() {
        final status = Get.find<AuthService>().status.value;
        if (status == AuthStatus.customerActive) {
          return const CustomerBottomNav(current: CustomerTab.producers);
        }
        return const SizedBox.shrink();
      }),
      body: Obx(() {
        if (_ctrl.isLoadingProfile.value && _ctrl.profile.value == null) {
          return const Scaffold(
            body: AppLoading(),
          );
        }
        if (_ctrl.profileError.value != null && _ctrl.profile.value == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Üretici')),
            body: AppErrorWidget(
              message: _ctrl.profileError.value!,
              onRetry: _ctrl.load,
            ),
          );
        }
        final p = _ctrl.profile.value;
        if (p == null) return const Scaffold(body: AppLoading());
        return _ProfileBody(
          profile: p,
          ctrl: _ctrl,
          scrollController: _scrollController,
          phoneRevealed: _phoneRevealed,
          onRevealPhone: () => setState(() => _phoneRevealed = true),
          onCall: _call,
          onCopy: _copy,
          onWhatsApp: () => _openWhatsApp(p.publicPhone),
        );
      }),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final FarmerProfile profile;
  final FarmerController ctrl;
  final ScrollController scrollController;
  final bool phoneRevealed;
  final VoidCallback onRevealPhone;
  final Future<void> Function(String) onCall;
  final Future<void> Function(String) onCopy;
  final Future<void> Function() onWhatsApp;

  const _ProfileBody({
    required this.profile,
    required this.ctrl,
    required this.scrollController,
    required this.phoneRevealed,
    required this.onRevealPhone,
    required this.onCall,
    required this.onCopy,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBio = profile.bio != null && profile.bio!.isNotEmpty;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // ── Hero SliverAppBar ──────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 340,
          pinned: true,
          stretch: true,
          leading: const BackButton(),
          actions: const [FarmerModeChip()],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (profile.profileImageUrl != null)
                  CachedNetworkImage(
                    imageUrl: profile.profileImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: cs.surfaceContainerLow,
                    ),
                    errorWidget: (_, __, ___) =>
                        _PlaceholderHero(cs: cs),
                  )
                else
                  _PlaceholderHero(cs: cs),
                // Gradient overlay for readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          cs.surface.withValues(alpha: 0.15),
                          cs.surface.withValues(alpha: 0.7),
                          cs.surface,
                        ],
                        stops: const [0.0, 0.45, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Profile Header Card (glass-panel) ─────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: _GlassProfileCard(profile: profile),
          ),
        ),

        // ── WhatsApp CTA (girişsiz çalışır) ────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: AppButton(
              label: 'WhatsApp ile İletişime Geç',
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: onWhatsApp,
            ),
          ),
        ),

        // ── Hikayemiz ─────────────────────────────────────────────────
        if (hasBio) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _SectionTitle(
                icon: Icons.history_edu_outlined,
                title: 'Hikayemiz',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _BioParagraphs(bio: profile.bio!),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],

        // ── İletişim ─────────────────────────────────────────────────
        if (profile.showPhone && (profile.publicPhone?.isNotEmpty ?? false)) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _ContactSection(
                phone: profile.publicPhone!,
                revealed: phoneRevealed,
                onReveal: onRevealPhone,
                onCall: onCall,
                onCopy: onCopy,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],

        // ── Ürünler ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined,
                    color: cs.primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${profile.displayName} Ürünleri',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

        Obx(() {
          if (ctrl.isLoadingProducts.value) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (ctrl.productsError.value != null) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Ürünler yüklenemedi',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }
          if (ctrl.products.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Bu üreticinin aktif ürünü yok.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductCard(product: ctrl.products[i]),
                childCount: ctrl.products.length,
              ),
            ),
          );
        }),

        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PlaceholderHero extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderHero({required this.cs});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerLow,
      child: Icon(Icons.person, size: 80, color: cs.onSurfaceVariant),
    );
  }
}

class _GlassProfileCard extends StatelessWidget {
  final FarmerProfile profile;
  const _GlassProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeLabel = producerTypeLabel(profile.producerType);
    final location = [
      profile.city,
      if (profile.district.isNotEmpty) profile.district,
    ].join(' · ');
    final tagline = '$typeLabel · $location';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tagline,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (profile.isFoundingFarmer)
                    const FoundingBadge()
                  else if (profile.isVerified)
                    const VerifiedBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: cs.secondary, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _BioParagraphs extends StatelessWidget {
  final String bio;
  const _BioParagraphs({required this.bio});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paragraphs = bio
        .split('\n\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                p,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final String phone;
  final bool revealed;
  final VoidCallback onReveal;
  final Future<void> Function(String) onCall;
  final Future<void> Function(String) onCopy;
  const _ContactSection({
    required this.phone,
    required this.revealed,
    required this.onReveal,
    required this.onCall,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.phone_outlined, title: 'İletişim'),
        const SizedBox(height: AppSpacing.sm),
        if (!revealed)
          AppButton(
            label: 'İletişim Bilgisini Göster',
            variant: AppButtonVariant.secondary,
            onPressed: onReveal,
            icon: const Icon(Icons.phone_outlined,
                color: AppColors.primaryContainer),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.phone, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    PhoneFormatter.pretty(phone),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Kopyala',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => onCopy(phone),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Ara',
                  onPressed: () => onCall(phone),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
