import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:koyden_sehire/app/app.dart';
import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/core/bindings/app_binding.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/core/services/onboarding_service.dart';
import 'package:koyden_sehire/core/services/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Refuse to launch a release build that hasn't been given an explicit
  // BASE_URL — the dev default points at the Android emulator host loopback
  // and is unreachable from a real device / app store build.
  if (kReleaseMode && AppConstants.isDevDefaultBaseUrl) {
    throw StateError(
      'BASE_URL is missing in release build. '
      'Pass --dart-define=BASE_URL=https://api.example.com/api/v1',
    );
  }

  if (!kReleaseMode && AppConstants.isDevDefaultBaseUrl) {
    debugPrint(
      '[BASE_URL] --dart-define=BASE_URL verilmedi, varsayılan kullanılıyor: '
      '${AppConstants.baseUrl}\n'
      '           Backend başka bir adresteyse: '
      'flutter run --dart-define=BASE_URL=http://<host>:8080/api/v1',
    );
  }

  // Firebase must be initialised before AppBinding so PushNotificationService
  // can call FirebaseMessaging.instance inside onInit().
  // Web'de FCM background handler desteklenmez, sadece init yapılır.
  // Wrapped in try-catch so the app boots without firebase config in dev.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    }
  } catch (e) {
    // Firebase project not configured or missing files.
    // Push notifications will be unavailable but the rest of the app works.
    debugPrint('[Firebase] initializeApp failed: $e');
  }

  await initializeDateFormatting('tr_TR');
  // Register all global services/repositories before runApp so screens can
  // resolve them synchronously via Get.find().
  AppBinding().dependencies();
  // Auth durumu router kurulmadan önce kesinleşmeli: deep link ile açılışta
  // splash hiç mount olmaz, bootstrap yalnızca burada garanti çalışır.
  await Get.find<AuthService>().bootstrap();
  // Onboarding "seen" bayrağı router redirect'inde senkron okunur; runApp
  // öncesinde belleğe alınmalı.
  await Get.find<OnboardingService>().bootstrap();
  runApp(const KoydenSehireApp());
}
