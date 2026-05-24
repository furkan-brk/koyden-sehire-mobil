import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/utils/turkish_chars.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/services/application_repository.dart';
import 'package:koyden_sehire/controllers/application_form_controller.dart';
import 'package:koyden_sehire/controllers/invite_validation_controller.dart';

class InviteEntryScreen extends StatefulWidget {
  final String? prefillCode;
  const InviteEntryScreen({super.key, this.prefillCode});

  @override
  State<InviteEntryScreen> createState() => _InviteEntryScreenState();
}

class _InviteEntryScreenState extends State<InviteEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final InviteValidationController _ctrl;
  late final ApplicationFormController _formCtrl;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.prefillCode ?? '');
    _ctrl = Get.put(InviteValidationController(Get.find<ApplicationRepository>()));
    _formCtrl = Get.put(
      ApplicationFormController(Get.find<ApplicationRepository>()),
      permanent: false,
    );
    if ((widget.prefillCode ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.validate(widget.prefillCode!);
      });
    }
  }

  @override
  void dispose() {
    Get.delete<InviteValidationController>();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _codeController.text.trim().toUpperCase();
    final ok = await _ctrl.validate(code);
    if (!mounted) return;
    if (!ok) {
      final err = _ctrl.errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  void _continue() {
    final info = _ctrl.info.value;
    if (info == null) return;
    _formCtrl.reset();
    _formCtrl.setInvite(info);
    context.push('/apply/form');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Üretici Başvurusu'),
        leading: context.canPop()
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: cs.primaryContainer.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: cs.primaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Davet sistemi kullanıcı kalitesini güvence altına alır.',
                          style: context.text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Davet Kodu', style: context.text.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Üretici başvuruları davet sistemiyle alınmaktadır. Lütfen size iletilen davet kodunu girin.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Davet Kodu',
                  hint: 'KYS-XXXXXX',
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  validator: Validators.inviteCode,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                    TextInputFormatter.withFunction((old, neu) {
                      return neu.copyWith(text: TurkishChars.toUpper(neu.text));
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Obx(() => AppButton(
                      label: 'Kodu Doğrula',
                      isLoading: _ctrl.isLoading.value,
                      onPressed: _ctrl.isLoading.value ? null : _validate,
                    )),
                Obx(() {
                  final info = _ctrl.info.value;
                  if (info == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 24),
                      _InviteInfoCard(
                        inviterName: info.inviterName,
                        remainingUses: info.remainingUses,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Başvuruya Devam Et',
                        onPressed: _continue,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteInfoCard extends StatelessWidget {
  final String? inviterName;
  final int remainingUses;
  const _InviteInfoCard({
    required this.inviterName,
    required this.remainingUses,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inviterName == null
                      ? 'Davet kodu doğrulandı.'
                      : '$inviterName sizi Köyden Şehre\'ye davet etti.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (remainingUses > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bu kodun $remainingUses kullanım hakkı kaldı.',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
