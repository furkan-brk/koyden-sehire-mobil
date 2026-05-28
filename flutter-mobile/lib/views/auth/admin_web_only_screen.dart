import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:koyden_sehire/app/theme.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/shared/widgets/app_button.dart';

class AdminWebOnlyScreen extends StatelessWidget {
  const AdminWebOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.admin_panel_settings_outlined,
                  size: 96, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Yönetici Hesabı',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Admin panel web üzerinden yönetilir.\n'
                'Bu hesapla mobil uygulamaya giriş yapamazsınız.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Çıkış Yap',
                variant: AppButtonVariant.destructive,
                onPressed: () async {
                  await Get.find<AuthService>().logout();
                  if (context.mounted) context.go('/');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
