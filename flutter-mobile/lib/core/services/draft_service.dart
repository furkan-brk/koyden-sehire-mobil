import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persists arbitrary draft state to a Hive box so unfinished forms survive
/// app restarts. Currently used by the farmer application wizard so a user
/// who closes the app mid-form can resume where they left off.
///
/// The service self-initialises Hive lazily on first read/write so callers
/// don't need to await any setup in main(). All exceptions are swallowed —
/// draft persistence is best-effort and must never break the active flow.
class DraftService extends GetxService {
  static const String farmerApplicationKey = 'farmer_application_draft';
  static const String _boxName = 'drafts';

  Box<dynamic>? _box;
  bool _initTried = false;

  Future<Box<dynamic>?> _open() async {
    if (_box != null) return _box;
    try {
      if (!_initTried) {
        _initTried = true;
        await Hive.initFlutter();
      }
      _box = await Hive.openBox<dynamic>(_boxName);
    } catch (_) {
      _box = null;
    }
    return _box;
  }

  Future<void> saveDraft(
    Map<String, dynamic> data, {
    String key = farmerApplicationKey,
  }) async {
    try {
      final box = await _open();
      await box?.put(key, {
        ...data,
        '_saved_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // best-effort
    }
  }

  Future<Map<String, dynamic>?> loadDraft({
    String key = farmerApplicationKey,
  }) async {
    try {
      final box = await _open();
      final raw = box?.get(key);
      if (raw is Map) {
        return Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  Future<void> clearDraft({String key = farmerApplicationKey}) async {
    try {
      final box = await _open();
      await box?.delete(key);
    } catch (_) {
      // ignore
    }
  }

  Future<bool> hasDraft({String key = farmerApplicationKey}) async {
    final d = await loadDraft(key: key);
    return d != null && d.isNotEmpty;
  }
}
