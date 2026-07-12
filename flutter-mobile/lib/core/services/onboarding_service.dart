import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tracks whether the user has seen the first-launch onboarding screens.
/// Backed by Hive (same lazy pattern as [DraftService]); on any storage
/// failure we default to "seen" so a broken store can never trap the user
/// in the onboarding flow.
class OnboardingService extends GetxService {
  static const String _boxName = 'app_prefs';
  static const String _seenKey = 'onboarding_seen';

  bool seen = true;
  Box<dynamic>? _box;

  Future<void> bootstrap() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<dynamic>(_boxName);
      seen = _box?.get(_seenKey) == true;
    } catch (_) {
      seen = true;
    }
  }

  Future<void> markSeen() async {
    seen = true;
    try {
      await _box?.put(_seenKey, true);
    } catch (_) {
      // best-effort
    }
  }
}
