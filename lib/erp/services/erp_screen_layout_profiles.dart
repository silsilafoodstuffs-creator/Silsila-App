import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared local cache and offline queue for company-scoped ERP layout profiles.
class ErpScreenLayoutProfiles {
  ErpScreenLayoutProfiles._();

  static const storageKey = 'silsila_screen_layout_profiles_v1';
  static const pendingStorageKey = 'silsila_screen_layout_pending_cloud_v1';
  static final ValueNotifier<Map<String, dynamic>> profiles =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});
  static final Set<String> _pendingKeys = <String>{};
  static bool _loaded = false;

  static Set<String> get pendingKeys => Set<String>.unmodifiable(_pendingKeys);

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) profiles.value = Map<String, dynamic>.from(decoded);
      }
      final pending = prefs.getStringList(pendingStorageKey) ?? const <String>[];
      _pendingKeys
        ..clear()
        ..addAll(pending);
    } finally {
      _loaded = true;
    }
  }

  static Map<String, dynamic> forScreen(String screen) {
    final exact = profiles.value[screen];
    final global = profiles.value['*'];
    return Map<String, dynamic>.from(
      exact is Map ? exact : global is Map ? global : const <String, dynamic>{},
    );
  }

  static Map<String, Map<String, dynamic>> pendingProfiles() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in _pendingKeys) {
      final value = profiles.value[key];
      if (value is Map) result[key] = Map<String, dynamic>.from(value);
    }
    return result;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(profiles.value))) {
      throw StateError('تعذر حفظ إعدادات تخطيط الشاشات محلياً.');
    }
    await prefs.setStringList(pendingStorageKey, _pendingKeys.toList());
  }

  static Future<void> save(String profileKey, Map<String, dynamic> profile) async {
    await load();
    final next = Map<String, dynamic>.from(profiles.value)
      ..[profileKey] = Map<String, dynamic>.from(profile);
    profiles.value = next;
    _pendingKeys.add(profileKey);
    await _persist();
  }

  /// Merge remote values without overwriting unsynchronized local edits.
  static Future<void> mergeRemote(Map<String, Map<String, dynamic>> remote) async {
    await load();
    final next = Map<String, dynamic>.from(profiles.value);
    for (final entry in remote.entries) {
      if (!_pendingKeys.contains(entry.key)) {
        next[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }
    profiles.value = next;
    await _persist();
  }

  static Future<void> markSynced(String profileKey) async {
    await load();
    _pendingKeys.remove(profileKey);
    await _persist();
  }

  static Future<void> reset(String profileKey) async {
    await load();
    final next = Map<String, dynamic>.from(profiles.value)..remove(profileKey);
    profiles.value = next;
    _pendingKeys.remove(profileKey);
    await _persist();
  }
}
