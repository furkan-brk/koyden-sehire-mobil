import 'package:flutter/material.dart';

/// Global ScaffoldMessengerKey — MaterialApp.router context dışından
/// SnackBar göstermek için kullanılır (örn. PushNotificationService).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
