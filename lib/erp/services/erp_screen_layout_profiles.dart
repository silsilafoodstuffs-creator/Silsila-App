import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache and offline queue for ERP layout profiles, isolated per company.
class ErpScreenLayoutProfiles {
  ErpScreenLayoutProfiles._();

  /// Legacy/local-only keys retained for backwards-compatible local settings.
  static const storageKey = 'silsila_screen_layout_profiles_v1';
  static const pendingStorageKey = 'silsila_screen_layout_pending_cloud_v1';
  static const legacyStorageKey = storageKey;
  static const legacyPendingStorageKey = pendingStorageKey;

  static final ValueNotifier<Map<String, dynamic>> profiles =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});
  static final Set<String> _pendingKeys = <String>{};
  static bool _loaded = false;
  static String? _activeScope;

  static String scopeForCompany(String? companyId) {
    final normalized = companyId?.trim() ?? '';
    if (normalized.isEmpty) return 'local';
    return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  }

  static String get _profilesKey =>
      _activeScope == null || _activeScope == 'local'
          ? storageKey
          : '${storageKey}__$_activeScope';

  static String get _pendingKey =>
      _activeScope == null || _activeScope == 'local'
          ? pendingStorageKey
          : '${pendingStorageKey}__$_activeScope';

  static Set<String> get pendingKeys =>
      Set<String>.unmodifiable(_pendingKeys);

  static Future<void> load({String? companyId}) async {
    final scope = scopeForCompany(companyId);
    if (_loaded && _activeScope == scope) return;

    // Never expose one company's in-memory values while switching scope.
    _activeScope = scope;
    _loaded = false;
    profiles.value = <String, dynamic>{};
    _pendingKeys.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          profiles.value = Map<String, dynamic>.from(decoded);
        }
      }

      final pending = prefs.getStringList(_pendingKey) ?? const <String>[];
      _pendingKeys.addAll(pending);
    } finally {
      _loaded = true;
    }
  }

  static bool _matchesScope(String? companyId) =>
      _activeScope == scopeForCompany(companyId);

  static Map<String, dynamic> forScreen(String screen) {
    final exact = profiles.value[screen];
    final global = profiles.value['*'];
    return Map<String, dynamic>.from(
      exact is Map
          ? exact
          : global is Map
              ? global
              : const <String, dynamic>{},
    );
  }

  static Map<String, Map<String, dynamic>> pendingProfiles({
    String? companyId,
  }) {
    if (!_matchesScope(companyId)) return <String, Map<String, dynamic>>{};
    final result = <String, Map<String, dynamic>>{};
    for (final key in _pendingKeys) {
      final value = profiles.value[key];
      if (value is Map) {
        result[key] = Map<String, dynamic>.from(value);
      }
    }
    return result;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_profilesKey, jsonEncode(profiles.value))) {
      throw StateError('تعذر حفظ إعدادات تخطيط الشاشات محلياً.');
    }
    if (!await prefs.setStringList(_pendingKey, _pendingKeys.toList())) {
      throw StateError('تعذر حفظ قائمة التخطيطات المعلقة للمزامنة.');
    }
  }

  static Future<void> save(
    String profileKey,
    Map<String, dynamic> profile, {
    String? companyId,
  }) async {
    await load(companyId: companyId);
    final next = Map<String, dynamic>.from(profiles.value)
      ..[profileKey] = Map<String, dynamic>.from(profile);
    profiles.value = next;
    _pendingKeys.add(profileKey);
    await _persist();
  }

  /// Merge remote values without overwriting unsynchronized local edits.
  static Future<void> mergeRemote(
    Map<String, Map<String, dynamic>> remote, {
    String? companyId,
  }) async {
    await load(companyId: companyId);
    final next = Map<String, dynamic>.from(profiles.value);
    for (final entry in remote.entries) {
      if (!_pendingKeys.contains(entry.key)) {
        next[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }
    profiles.value = next;
    await _persist();
  }

  static Future<void> markSynced(
    String profileKey, {
    String? companyId,
  }) async {
    await load(companyId: companyId);
    _pendingKeys.remove(profileKey);
    await _persist();
  }

  static Future<void> reset(
    String profileKey, {
    String? companyId,
  }) async {
    await load(companyId: companyId);
    final next = Map<String, dynamic>.from(profiles.value)..remove(profileKey);
    profiles.value = next;
    _pendingKeys.remove(profileKey);
    await _persist();
  }
}
