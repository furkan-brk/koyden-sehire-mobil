import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart' hide Trans;

import 'package:koyden_sehire/core/services/connectivity_service.dart';
import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/keys.dart';
import 'package:koyden_sehire/app/router.dart';
import 'package:koyden_sehire/app/theme.dart';

class KoydenSehireApp extends StatelessWidget {
  const KoydenSehireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: AppRouter.router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Obx(() {
          final offline = !Get.find<ConnectivityService>().isOnline.value;
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (offline) const _OfflineBanner(),
            ],
          );
        });
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Material(
          color: AppColors.error,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'İnternet bağlantısı yok',
                    style: TextStyle(color: Colors.white, fontSize: 12),
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
