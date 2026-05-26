import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

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
    if (kIsWeb) return; // Admin web paneli push bildirimi kullanmaz
    await _initLocalNotifications();
    await _requestPermission();
    _listenForeground();
    _listenTokenRefresh();
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerCurrentToken();
    }
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
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
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _currentToken = token;
      await _registerTokenWithBackend(token);
    } catch (e) {
      // Non-fatal — user can still use the app without push notifications.
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final auth = Get.find<AuthService>();
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : 'android';
    try {
      switch (auth.status.value) {
        case AuthStatus.farmerActive:
          await _repo.registerFarmer(token, platform);
        case AuthStatus.customerActive:
          await _repo.registerCustomer(token, platform);
        default:
          break;
      }
    } catch (_) {
      // Backend unavailable or user not authenticated yet — will retry on next login.
    }
  }

  /// Call after a successful login to register the token for the newly
  /// authenticated role.
  Future<void> onLogin() async {
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
    try {
      switch (auth.status.value) {
        case AuthStatus.farmerActive:
          await _repo.unregisterFarmer(token);
        case AuthStatus.customerActive:
          await _repo.unregisterCustomer(token);
        default:
          break;
      }
    } catch (_) {}
    _currentToken = null;
  }
}
