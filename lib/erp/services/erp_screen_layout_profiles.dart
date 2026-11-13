import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared profile cache consumed by the common ERP frame and the layout editor.
class ErpScreenLayoutProfiles {
  ErpScreenLayoutProfiles._();

  static const storageKey = 'silsila_screen_layout_profiles_v1';
  static final ValueNotifier<Map<String, dynamic>> profiles =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          profiles.value = Map<String, dynamic>.from(decoded);
        }
      }
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

  static Future<void> save(String screen, Map<String, dynamic> profile) async {
    await load();
    final next = Map<String, dynamic>.from(profiles.value)..[screen] = Map<String, dynamic>.from(profile);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(next))) {
      throw StateError('تعذر حفظ إعدادات تخطيط الشاشات.');
    }
    profiles.value = next;
  }

  static Future<void> reset(String screen) async {
    await load();
    final next = Map<String, dynamic>.from(profiles.value)..remove(screen);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(next));
    profiles.value = next;
  }
}
