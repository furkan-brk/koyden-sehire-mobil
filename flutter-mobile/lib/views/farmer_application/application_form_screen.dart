import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/shared/widgets/app_loading.dart';
import 'package:koyden_sehire/core/errors/app_exception.dart';
import 'package:koyden_sehire/core/utils/phone_formatter.dart';
import 'package:koyden_sehire/core/utils/validators.dart';
import 'package:koyden_sehire/shared/extensions/context_extensions.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';
import 'package:koyden_sehire/shared/widgets/app_text_field.dart';
import 'package:koyden_sehire/shared/widgets/category_chip.dart';
import 'package:koyden_sehire/shared/widgets/otp_input.dart';
import 'package:koyden_sehire/shared/widgets/otp_resend_button.dart';
import 'package:koyden_sehire/services/category_repository.dart';
import 'package:koyden_sehire/services/otp_repository.dart';
import 'package:koyden_sehire/controllers/public/category_controller.dart';
import 'package:koyden_sehire/models/farmer_model.dart';
import 'package:koyden_sehire/controllers/application_form_controller.dart';
import 'package:koyden_sehire/models/selected_location.dart';
import 'package:koyden_sehire/views/farmer_application/select_location_screen.dart';

const _stepTitles = [
  'Telefon Doğrulama',
  'Kişisel & Çiftlik Bilgileri',
  'Üretim & Video',
  'Şartlar ve Gönder',
];

ApplicationFormController _formCtrl() => Get.find<ApplicationFormController>();

class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({super.key});

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferResume());
  }

  Future<void> _maybeOfferResume() async {
    final ctrl = _formCtrl();
    // If the wizard is already populated (e.g. user typed into step 1 before
    // any persistence kicked in) we do not overwrite their input.
    final hasUserInput = ctrl.data.value.fullName.isNotEmpty ||
        ctrl.data.value.businessName.isNotEmpty ||
        ctrl.currentStep.value > 0;
    if (hasUserInput) return;
    final hasDraft = await ctrl.hasDraft();
    if (!hasDraft || !mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Devam etmek ister misiniz?'),
        content: const Text(
          'Yarım kalan bir başvurunuz var. Kaldığınız yerden devam '
          'etmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır, Yeniden Başla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Devam Et'),
          ),
        ],
      ),
    );
    if (resume == true) {
      await ctrl.restoreDraft();
    } else {
      await ctrl.clearDraft();
    }
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Formu terk etmek istediğinize emin misiniz?'),
        content: const Text('Girdiğiniz bilgiler silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terk Et'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _formCtrl();

    return Obx(() {
      if (ctrl.invite.value == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/apply');
        });
        return const Scaffold();
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final confirm = await _confirmExit();
          if (!confirm) return;
          if (!mounted) return;
          if (!context.mounted) return;
          ctrl.reset();
          if (!context.mounted) return;
          context.go('/');
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('Adım ${ctrl.currentStep.value + 1} / 4'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final confirm = await _confirmExit();
                if (!confirm) return;
                if (!context.mounted) return;
                ctrl.reset();
                if (!context.mounted) return;
                context.go('/');
              },
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                _StepIndicator(
                  currentStep: ctrl.currentStep.value,
                  totalSteps: 4,
                  title: _stepTitles[ctrl.currentStep.value],
                ),
                Expanded(
                  child: IndexedStack(
                    index: ctrl.currentStep.value,
                    children: const [
                      _StepPhone(),
                      _StepPersonalFarm(),
                      _StepProductionVideo(),
                      _StepTerms(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String title;
  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / totalSteps,
              minHeight: 6,
              backgroundColor: AppColors.outlineVariant,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

// -- STEP 1: Inline phone verification ------------------------------------

class _StepPhone extends StatefulWidget {
  const _StepPhone();
  @override
  State<_StepPhone> createState() => _StepPhoneState();
}

class _StepPhoneState extends State<_StepPhone> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();

  bool _codeSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  String _otpCode = '';
  String? _error;

  late final OtpRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = Get.find<OtpRepository>();
    _phone.text = _formCtrl().data.value.phone;
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await _repo.send(_phone.text.trim());
      if (mounted) {
        setState(() {
          _codeSent = true;
          _isSending = false;
        });
      }
    } on AppException catch (e) {
      String msg = e.message;
      if (e.code == 'COOLDOWN_ACTIVE') {
        msg = 'Az önce gönderildi, biraz bekleyin.';
        if (mounted) setState(() => _codeSent = true);
      } else if (e.code == 'INVALID_PHONE') {
        msg = 'Geçersiz telefon numarası';
      }
      if (mounted) {
        setState(() {
          _error = msg;
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Kod gönderilemedi';
          _isSending = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    try {
      await _repo.send(_phone.text.trim());
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Kod gönderilemedi');
    }
  }

  Future<void> _verify() async {
    if (_otpCode.length != AppConstants.otpLength) return;
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await _repo.verify(phone: _phone.text.trim(), code: _otpCode);
      if (!mounted) return;
      _formCtrl().updateData((d) => d.copyWith(phone: _phone.text.trim()));
      _formCtrl().setPhoneVerified(true);
      setState(() => _isVerifying = false);
    } on AppException catch (e) {
      String msg = e.message;
      if (e.code == 'INVALID_CODE') {
        msg = 'Kod hatalı, tekrar deneyin';
      } else if (e.code == 'OTP_EXPIRED') {
        msg = 'Kodun süresi doldu, tekrar gönderin';
      } else if (e.code == 'MAX_ATTEMPTS') {
        msg = 'Çok fazla yanlış deneme. Yeni kod isteyin.';
      }
      if (mounted) {
        setState(() {
          _error = msg;
          _isVerifying = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Doğrulama başarısız';
          _isVerifying = false;
        });
      }
    }
  }

  void _resetPhone() {
    _formCtrl().setPhoneVerified(false);
    setState(() {
      _codeSent = false;
      _otpCode = '';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final verified = _formCtrl().phoneVerified.value;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Başvurunuzu işleme alabilmemiz için telefon numaranızı doğrulamanız gerekiyor.',
              style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (verified) ...[
              _PhoneVerifiedBadge(phone: _phone.text),
              const SizedBox(height: 24),
              AppButton(
                label: 'Devam Et',
                onPressed: () => _formCtrl().next(),
              ),
            ] else ...[
              Form(
                key: _formKey,
                child: AppTextField(
                  label: 'Telefon (05XXXXXXXXX)',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: Validators.phone,
                  enabled: !_codeSent,
                ),
              ),
              if (_codeSent)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPhone,
                    child: const Text('Numarayı Değiştir'),
                  ),
                )
              else
                const SizedBox(height: 12),
              if (!_codeSent)
                AppButton(
                  label: 'SMS Kodu Gönder',
                  isLoading: _isSending,
                  onPressed: _isSending ? null : _sendCode,
                  icon: const Icon(Icons.sms_outlined, color: Colors.white),
                )
              else ...[
                Text(
                  '${PhoneFormatter.mask(_phone.text)} numarasına 6 haneli doğrulama kodu gönderdik.',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                OtpInput(
                  length: AppConstants.otpLength,
                  onChanged: (v) => setState(() {
                    _otpCode = v;
                    _error = null;
                  }),
                  onCompleted: (_) => _verify(),
                  enabled: !_isVerifying,
                  errorText: _error,
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Doğrula',
                  isLoading: _isVerifying,
                  onPressed: _otpCode.length == AppConstants.otpLength &&
                          !_isVerifying
                      ? _verify
                      : null,
                ),
                const SizedBox(height: 12),
                Center(child: OtpResendButton(onResend: _resendCode)),
              ],
            ],
          ],
        ),
      );
    });
  }
}

class _PhoneVerifiedBadge extends StatelessWidget {
  final String phone;
  const _PhoneVerifiedBadge({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Telefon numarası doğrulandı',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- STEP 2: Personal info + farm info ------------------------------------

class _StepPersonalFarm extends StatefulWidget {
  const _StepPersonalFarm();
  @override
  State<_StepPersonalFarm> createState() => _StepPersonalFarmState();
}

class _StepPersonalFarmState extends State<_StepPersonalFarm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _businessName = TextEditingController();
  final _bio = TextEditingController();
  String? _producerType;
  SelectedLocation? _selectedLocation;

  @override
  void initState() {
    super.initState();
    final d = _formCtrl().data.value;
    _name.text = d.fullName;
    _email.text = d.email ?? '';
    _password.text = d.password;
    _businessName.text = d.businessName;
    _bio.text = d.bio;
    _producerType = d.producerType;
    if (d.city.isNotEmpty) {
      _selectedLocation = SelectedLocation(
        city: d.city,
        district: d.district,
        village: d.village,
        formattedAddress:
            [d.district, d.city].where((s) => s.isNotEmpty).join(', '),
        lat: 0,
        lng: 0,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _businessName.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    _formCtrl().updateData(
      (d) => d.copyWith(
        fullName: _name.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        password: _password.text,
        businessName: _businessName.text.trim(),
        producerType: _producerType,
        city: _selectedLocation?.city ?? '',
        district: _selectedLocation?.district ?? '',
        village: _selectedLocation?.village ?? '',
        bio: _bio.text.trim(),
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<SelectedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(initial: _selectedLocation),
      ),
    );
    if (result != null) {
      setState(() => _selectedLocation = result);
    }
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_producerType == null) {
      context.snack('Üretici tipi seçin', isError: true);
      return;
    }
    if (_selectedLocation == null) {
      context.snack('Lütfen çiftlik konumunu haritadan seçin', isError: true);
      return;
    }
    _save();
    _formCtrl().next();
  }

  void _back() {
    _save();
    _formCtrl().previous();
  }

  @override
  Widget build(BuildContext context) {
    final loc = _selectedLocation;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kişisel Bilgiler',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Ad Soyad',
              controller: _name,
              validator: (v) => Validators.required(v, field: 'Ad Soyad'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'E-posta (isteğe bağlı)',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Şifre',
              controller: _password,
              obscureText: true,
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Şifre Tekrar',
              controller: _passwordConfirm,
              obscureText: true,
              validator: Validators.confirmPassword(() => _password.text),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Çiftlik / İşletme Bilgileri',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Üretici / İşletme Adı',
              hint: "Mehmet Amca'nın Çiftliği",
              controller: _businessName,
              validator: (v) => Validators.required(v, field: 'İşletme adı'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _producerType,
              decoration: const InputDecoration(labelText: 'Üretici Tipi'),
              items: producerTypeLabels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _producerType = v),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _openLocationPicker,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: loc == null
                        ? AppColors.outlineVariant
                        : AppColors.primaryContainer,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: loc == null
                      ? Colors.transparent
                      : AppColors.primaryFixed.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      loc == null
                          ? Icons.add_location_alt_outlined
                          : Icons.location_on,
                      color: loc == null
                          ? AppColors.onSurfaceVariant
                          : AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc == null
                                ? 'Çiftlik Konumunu Seç *'
                                : 'Çiftlik Konumu',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: loc == null
                                  ? AppColors.onSurfaceVariant
                                  : AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (loc != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              loc.formattedAddress.isNotEmpty
                                  ? loc.formattedAddress
                                  : [loc.district, loc.city]
                                      .where((s) => s.isNotEmpty)
                                      .join(', '),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ] else
                            const Text(
                              'Haritadan çiftlik adresinizi belirleyin',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: AppColors.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Kısa Biyografi',
              hint:
                  "Bursa Kestel'de ailemizle birlikte çilek ve sebze üretimi yapıyoruz.",
              controller: _bio,
              maxLines: 4,
              validator: (v) => Validators.required(v, field: 'Biyografi'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Geri',
                    variant: AppButtonVariant.secondary,
                    onPressed: _back,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(label: 'Devam Et', onPressed: _continue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -- STEP 3: Production info + optional video -----------------------------

class _StepProductionVideo extends StatefulWidget {
  const _StepProductionVideo();
  @override
  State<_StepProductionVideo> createState() => _StepProductionVideoState();
}

class _StepProductionVideoState extends State<_StepProductionVideo> {
  final _formKey = GlobalKey<FormState>();
  final _examples = TextEditingController();
  final _note = TextEditingController();
  Set<String> _selectedSlugs = {};
  String? _placeType;
  bool _videoExpanded = false;
  File? _videoFile;
  int? _videoSize;

  late final CategoryController _cats;

  @override
  void initState() {
    super.initState();
    _cats = Get.isRegistered<CategoryController>()
        ? Get.find<CategoryController>()
        : Get.put(CategoryController(Get.find<CategoryRepository>()),
            permanent: true);
    final d = _formCtrl().data.value;
    _examples.text = d.productExamples;
    _note.text = d.applicationNote ?? '';
    _selectedSlugs = d.productCategorySlugs.toSet();
    _placeType = d.productionPlaceType;
    _videoExpanded = d.applicationVideoKey != null;
  }

  @override
  void dispose() {
    _examples.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    _formCtrl().updateData(
      (d) => d.copyWith(
        productCategorySlugs: _selectedSlugs.toList(),
        productExamples: _examples.text.trim(),
        productionPlaceType: _placeType,
        applicationNote:
            _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 90),
      );
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > AppConstants.maxApplicationVideoBytes) {
        if (!mounted) return;
        context.snack(
          "Video boyutu 50 MB'ı aşıyor. Lütfen daha kısa bir video seçin.",
          isError: true,
        );
        return;
      }
      setState(() {
        _videoFile = file;
        _videoSize = size;
      });
    } catch (_) {
      if (mounted) context.snack('Video seçilemedi', isError: true);
    }
  }

  Future<void> _uploadVideo() async {
    final file = _videoFile;
    if (file == null) return;
    final ok = await _formCtrl().uploadVideo(file);
    if (!mounted) return;
    if (ok) {
      context.toast('Video yüklendi');
    } else {
      final err = _formCtrl().errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedSlugs.isEmpty) {
      context.snack('En az bir kategori seçin', isError: true);
      return;
    }
    _save();
    _formCtrl().next();
  }

  void _back() {
    _save();
    _formCtrl().previous();
  }

  String _bytesPretty(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isUploading = _formCtrl().isUploading.value;
      final uploadProgress = _formCtrl().uploadProgress.value;
      final videoKey = _formCtrl().data.value.applicationVideoKey;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ürün Kategorileri',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Obx(() {
                if (_cats.isLoading.value) {
                  return const AppLoading();
                }
                if (_cats.error.value != null) {
                  return const Text(
                    'Kategoriler yüklenemedi',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  );
                }
                final roots =
                    _cats.categories.where((c) => c.isRoot).toList();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roots.map((c) {
                    final selected = _selectedSlugs.contains(c.slug);
                    return AppCategoryChip(
                      label: c.name,
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedSlugs.remove(c.slug);
                        } else {
                          _selectedSlugs.add(c.slug);
                        }
                      }),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Ürün Örnekleri',
                hint: 'Çilek, domates, salatalık, köy yumurtası',
                controller: _examples,
                maxLines: 2,
                validator: (v) =>
                    Validators.required(v, field: 'Ürün örnekleri'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _placeType,
                decoration: const InputDecoration(
                    labelText: 'Üretim Yeri (isteğe bağlı)'),
                items: productionPlaceLabels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _placeType = v),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Başvuru Notu (isteğe bağlı)',
                hint: 'Eklemek istediğiniz bilgiler...',
                controller: _note,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _VideoSection(
                expanded: _videoExpanded,
                onToggle: () =>
                    setState(() => _videoExpanded = !_videoExpanded),
                videoFile: _videoFile,
                videoSize: _videoSize,
                isUploading: isUploading,
                uploadProgress: uploadProgress,
                videoKey: videoKey,
                bytesPretty: _bytesPretty,
                onPickCamera: () => _pickVideo(ImageSource.camera),
                onPickGallery: () => _pickVideo(ImageSource.gallery),
                onRemoveVideo: () =>
                    setState(() {
                      _videoFile = null;
                      _videoSize = null;
                    }),
                onUpload: _uploadVideo,
                onClearVideo: () {
                  _formCtrl()
                      .updateData((d) => d.copyWith(clearVideoKey: true));
                  setState(() {
                    _videoFile = null;
                    _videoSize = null;
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Geri',
                      variant: AppButtonVariant.secondary,
                      onPressed: isUploading ? null : _back,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: 'Devam Et',
                      onPressed: isUploading ? null : _continue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _VideoSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final File? videoFile;
  final int? videoSize;
  final bool isUploading;
  final double uploadProgress;
  final String? videoKey;
  final String Function(int) bytesPretty;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemoveVideo;
  final VoidCallback onUpload;
  final VoidCallback onClearVideo;

  const _VideoSection({
    required this.expanded,
    required this.onToggle,
    required this.videoFile,
    required this.videoSize,
    required this.isUploading,
    required this.uploadProgress,
    required this.videoKey,
    required this.bytesPretty,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemoveVideo,
    required this.onUpload,
    required this.onClearVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(AppRadius.md))
                : BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    videoKey != null
                        ? Icons.videocam
                        : Icons.videocam_outlined,
                    color: videoKey != null
                        ? AppColors.primaryContainer
                        : AppColors.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Tanıtım Videosu',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.outlineVariant
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'İsteğe Bağlı',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          videoKey != null
                              ? 'Video yüklendi ✓'
                              : 'Başvurunuzu hızlandırır',
                          style: TextStyle(
                            fontSize: 12,
                            color: videoKey != null
                                ? AppColors.success
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Videoda ne söylenmeli?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Adınızı, nerede üretim yaptığınızı ve hangi ürünleri ürettiğinizi söylemeniz yeterlidir. Mümkünse ürünlerinizi, bahçenizi veya üretim alanınızı da gösterebilirsiniz.',
                        ),
                        SizedBox(height: 8),
                        Text('• 30-60 saniye önerilen, maksimum 90 saniye'),
                        Text('• Maksimum 50 MB'),
                        Text('• MP4 veya MOV formatı'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (videoKey != null && videoFile == null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color:
                                AppColors.secondary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success),
                          const SizedBox(width: 12),
                          const Expanded(
                              child: Text('Video başarıyla yüklendi')),
                          TextButton(
                            onPressed: onClearVideo,
                            child: const Text('Kaldır'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (videoFile == null) ...[
                    AppButton(
                      label: 'Kameradan Çek',
                      icon: const Icon(Icons.videocam_outlined,
                          color: Colors.white),
                      onPressed: onPickCamera,
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Galeriden Seç',
                      variant: AppButtonVariant.secondary,
                      icon: const Icon(Icons.photo_library_outlined,
                          color: AppColors.primaryContainer),
                      onPressed: onPickGallery,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.movie_outlined,
                              color: AppColors.primaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  videoFile!.path.split('/').last,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (videoSize != null)
                                  Text(
                                    bytesPretty(videoSize!),
                                    style: const TextStyle(
                                        color: AppColors.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed:
                                isUploading ? null : onRemoveVideo,
                          ),
                        ],
                      ),
                    ),
                    if (isUploading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: uploadProgress),
                      const SizedBox(height: 4),
                      Text(
                        'Yükleniyor ${(uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Yükle',
                      isLoading: isUploading,
                      onPressed: isUploading ? null : onUpload,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primaryContainer.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline,
                            color: AppColors.primaryContainer, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Bu video yalnızca başvurunuzu değerlendiren Köyden Şehre ekibi tarafından görüntülenir.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryContainer,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -- STEP 4: Terms & submit -----------------------------------------------

class _StepTerms extends StatefulWidget {
  const _StepTerms();
  @override
  State<_StepTerms> createState() => _StepTermsState();
}

class _StepTermsState extends State<_StepTerms> {
  bool _kvkk = false;
  bool _platform = false;
  bool _own = false;
  bool _location = false;
  bool _notIntermediary = false;

  @override
  void initState() {
    super.initState();
    final d = _formCtrl().data.value;
    _kvkk = d.kvkkAccepted;
    _platform = d.platformTermsAccepted;
    _own = d.declaresOwnProduction;
    _location = d.declaresAccurateLocation;
    _notIntermediary = d.declaresNotIntermediary;
  }

  bool get _allAccepted =>
      _kvkk && _platform && _own && _location && _notIntermediary;

  Future<void> _submit() async {
    _formCtrl().updateData(
      (d) => d.copyWith(
        kvkkAccepted: _kvkk,
        platformTermsAccepted: _platform,
        declaresOwnProduction: _own,
        declaresAccurateLocation: _location,
        declaresNotIntermediary: _notIntermediary,
      ),
    );
    final ok = await _formCtrl().submit();
    if (!mounted) return;
    if (ok) {
      context.go('/apply/success');
    } else {
      final err = _formCtrl().errorMessage.value;
      if (err != null) context.snack(err, isError: true);
    }
  }

  void _back() => _formCtrl().previous();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSubmitting = _formCtrl().isSubmitting.value;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CheckTile(
              value: _kvkk,
              onChanged: (v) => setState(() => _kvkk = v),
              text: 'KVKK aydınlatma metnini okudum ve kabul ediyorum.',
            ),
            _CheckTile(
              value: _platform,
              onChanged: (v) => setState(() => _platform = v),
              text:
                  "Köyden Şehre'nin ödeme, sipariş, kargo veya uygulama içi mesajlaşma yapmadığını anlıyorum.",
            ),
            _CheckTile(
              value: _own,
              onChanged: (v) => setState(() => _own = v),
              text:
                  'Verdiğim bilgilerin doğru olduğunu ve kendi üretimimi sattığımı onaylıyorum.',
            ),
            _CheckTile(
              value: _notIntermediary,
              onChanged: (v) => setState(() => _notIntermediary = v),
              text: 'Aracı olmadığımı beyan ediyorum.',
            ),
            _CheckTile(
              value: _location,
              onChanged: (v) => setState(() => _location = v),
              text:
                  'Üretim yaptığım konum bilgilerini doğru girdiğimi onaylıyorum.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text(
                AppConstants.platformInfoText,
                style: TextStyle(
                    color: AppColors.primaryContainer, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Geri',
                    variant: AppButtonVariant.secondary,
                    onPressed: isSubmitting ? null : _back,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Başvuruyu Gönder',
                    isLoading: isSubmitting,
                    onPressed:
                        _allAccepted && !isSubmitting ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _CheckTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  const _CheckTile({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(text, style: const TextStyle(height: 1.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
