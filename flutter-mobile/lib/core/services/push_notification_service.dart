import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'package:koyden_sehire/app/constants.dart';
import 'package:koyden_sehire/app/keys.dart';
import 'package:koyden_sehire/core/services/auth_service.dart';
import 'package:koyden_sehire/models/auth/auth_state.dart';
import 'package:koyden_sehire/services/push_token_repository.dart';

/// Top-level background handler — must be a free function, not a class method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by main.dart before this fires.
  // No UI interaction possible here; the message will be shown by the OS.
}

class PushNotificationService extends GetxService {
  final PushTokenRepository _repo;
  PushNotificationService(this._repo);

  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;

  static const _androidChannel = AndroidNotificationChannel(
    'koyden_sehire_high',
    'Köyden Şehre Bildirimleri',
    description: 'Ürün onayları ve üretici güncellemeleri',
    importance: Importance.high,
  );

  @override
  Future<void> onInit() async {
    super.onInit();
    try {
      if (!kIsWeb) {
        await _initLocalNotifications();
      }
      await _requestPermission();
      _listenForeground();
      _listenTokenRefresh();
    } catch (e) {
      // Firebase not configured — push notifications disabled.
      debugPrint('[PushNotificationService] init skipped: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[Push] İzin durumu: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerCurrentToken();
    } else {
      debugPrint('[Push] Bildirim izni verilmedi — token kaydı atlandı');
    }
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      if (kIsWeb) {
        // Web'de flutter_local_notifications desteklenmez — SnackBar göster
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title ?? 'Bildirim',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if ((notification.body ?? '').isNotEmpty)
                        Text(
                          notification.body!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  void _listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _registerTokenWithBackend(newToken);
    });
  }

  Future<void> _registerCurrentToken() async {
    try {
      debugPrint('[Push] getToken() çağrılıyor...');
      // Web FCM için VAPID key zorunlu; mobil'de gerek yok.
      final token = kIsWeb && AppConstants.vapidKey.isNotEmpty
          ? await FirebaseMessaging.instance.getToken(
              vapidKey: AppConstants.vapidKey,
            )
          : await FirebaseMessaging.instance.getToken();
      debugPrint(
        '[Push] getToken() sonucu: ${token == null ? "NULL" : "${token.substring(0, 20)}..."}',
      );
      if (token == null) return;
      _currentToken = token;
      await _registerTokenWithBackend(token);
    } catch (e, st) {
      // Non-fatal — user can still use the app without push notifications.
      debugPrint('[Push] _registerCurrentToken HATA: $e\n$st');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final auth = Get.find<AuthService>();
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : 'android';
    debugPrint(
      '[Push] _registerTokenWithBackend — status: ${auth.status.value}, platform: $platform',
    );
    try {
      switch (auth.status.value) {
        case AuthStatus.farmerActive:
          await _repo.registerFarmer(token, platform);
          debugPrint('[Push] Farmer token backend\'e kaydedildi ✓');
        case AuthStatus.customerActive:
          await _repo.registerCustomer(token, platform);
          debugPrint('[Push] Customer token backend\'e kaydedildi ✓');
        case AuthStatus.admin:
          // Admin push token backend endpoint'i henüz yok — atla.
          debugPrint('[Push] Admin rolü için push token endpoint yok — atlandı');
        default:
          debugPrint(
            '[Push] Kimlik doğrulanmamış — token kaydı ertelendi: ${auth.status.value}',
          );
          break;
      }
    } catch (e, st) {
      // Backend unavailable or user not authenticated yet — will retry on next login.
      debugPrint('[Push] _registerTokenWithBackend HATA: $e\n$st');
    }
  }

  /// Call after a successful login to register the token for the newly
  /// authenticated role.
  Future<void> onLogin() async {
    debugPrint(
      '[Push] onLogin() çağrıldı — _currentToken: ${_currentToken == null ? "null" : "mevcut"}',
    );
    final token = _currentToken;
    if (token == null) {
      await _registerCurrentToken();
    } else {
      await _registerTokenWithBackend(token);
    }
  }

  /// Call before logout to deregister the token from the backend.
  Future<void> onLogout() async {
    final token = _currentToken;
    if (token == null) return;

    final auth = Get.find<AuthService>();
    final platform = kIsWeb ? 'web' : Platform.isIOS ? 'ios' : 'android';
    try {
      switch (auth.status.value) {
        case AuthStatus.farmerActive:
          await _repo.unregisterFarmer(token);
        case AuthStatus.customerActive:
          await _repo.unregisterCustomer(token);
        default:
          break;
      }
      debugPrint('[Push] Token backend\'den silindi ($platform)');
    } catch (_) {}
    _currentToken = null;
  }
}
