import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:koyden_sehire/app/app.dart';
import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/core/bindings/app_binding.dart';
import 'package:koyden_sehire/core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Refuse to launch a release build that hasn't been given an explicit
  // BASE_URL — the dev default points at the Android emulator host loopback
  // and is unreachable from a real device / app store build.
  if (kReleaseMode && AppConstants.isDevDefaultBaseUrl) {
    throw StateError(
      'BASE_URL is missing in release build. '
      'Pass --dart-define=BASE_URL=https://api.example.com/api/v1',
    );
  }

  // Firebase must be initialised before AppBinding so PushNotificationService
  // can call FirebaseMessaging.instance inside onInit().
  // Wrapped in try-catch so the app boots without google-services.json in dev.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // google-services.json missing or Firebase project not configured.
    // Push notifications will be unavailable but the rest of the app works.
    debugPrint('[Firebase] initializeApp failed: $e');
  }

  await initializeDateFormatting('tr_TR');
  // Register all global services/repositories before runApp so screens can
  // resolve them synchronously via Get.find().
  AppBinding().dependencies();
  runApp(const KoydenSehireApp());
}
