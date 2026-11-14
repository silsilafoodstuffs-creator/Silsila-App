import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Company-scoped local cache and offline queue for ERP layout profiles.
/// Legacy unscoped settings are quarantined in the local-only namespace.
class ErpScreenLayoutProfiles {
  ErpScreenLayoutProfiles._();

  static const legacyStorageKey = 'silsila_screen_layout_profiles_v1';
  static const legacyPendingStorageKey = 'silsila_screen_layout_pending_cloud_v1';
  static final ValueNotifier<Map<String, dynamic>> profiles =
      ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});
  static final Set<String> _pendingKeys = <String>{};
  static String _activeScope = 'local';
  static String? _loadedScope;

  static String scopeForCompany(String? companyId) {
    final value = companyId?.trim();
    if (value == null || value.isEmpty) return 'local';
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  static String _storageKey(String scope) => 'silsila_screen_layout_profiles_v2_$scope';
  static String _pendingStorageKey(String scope) => 'silsila_screen_layout_pending_v2_$scope';

  static Set<String> get pendingKeys => Set<String>.unmodifiable(_pendingKeys);

  static Future<void> load({String? companyId}) async {
    final scope = scopeForCompany(companyId);
    if (_loadedScope == scope) {
      _activeScope = scope;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> loadedProfiles = <String, dynamic>{};
    Set<String> loadedPending = <String>{};
    final raw = prefs.getString(_storageKey(scope));
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) loadedProfiles = Map<String, dynamic>.from(decoded);
    }

    final pending = prefs.getStringList(_pendingStorageKey(scope)) ?? const <String>[];
    loadedPending.addAll(pending);

    // Preserve pre-company-scoping data, but never assign it to a company
    // automatically: the original company owner cannot be inferred safely.
    if (scope == 'local' && raw == null) {
      final legacy = prefs.getString(legacyStorageKey);
      if (legacy != null && legacy.isNotEmpty) {
        final decoded = jsonDecode(legacy);
        if (decoded is Map) loadedProfiles = Map<String, dynamic>.from(decoded);
        final legacyPending = prefs.getStringList(legacyPendingStorageKey) ?? const <String>[];
        loadedPending.addAll(legacyPending);
        await prefs.setString(_storageKey('local'), jsonEncode(loadedProfiles));
        await prefs.setStringList(_pendingStorageKey('local'), loadedPending.toList());
        await prefs.remove(legacyStorageKey);
        await prefs.remove(legacyPendingStorageKey);
      }
    }

    _activeScope = scope;
    _loadedScope = scope;
    _pendingKeys
      ..clear()
      ..addAll(loadedPending);
    profiles.value = loadedProfiles;
  }

  static Map<String, dynamic> forScreen(String screen) {
    final exact = profiles.value[screen];
    final global = profiles.value['*'];
    return Map<String, dynamic>.from(
      exact is Map ? exact : global is Map ? global : const <String, dynamic>{},
    );
  }

  static Map<String, Map<String, dynamic>> pendingProfiles({String? companyId}) {
    if (scopeForCompany(companyId) != _activeScope) return <String, Map<String, dynamic>>{};
    final result = <String, Map<String, dynamic>>{};
    for (final key in _pendingKeys) {
      final value = profiles.value[key];
      if (value is Map) result[key] = Map<String, dynamic>.from(value);
    }
    return result;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_storageKey(_activeScope), jsonEncode(profiles.value))) {
      throw StateError('تعذر حفظ إعدادات تخطيط الشاشات محلياً.');
    }
    await prefs.setStringList(_pendingStorageKey(_activeScope), _pendingKeys.toList());
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

  static Future<void> markSynced(String profileKey, {String? companyId}) async {
    await load(companyId: companyId);
    _pendingKeys.remove(profileKey);
    await _persist();
  }

  static Future<void> reset(String profileKey, {String? companyId}) async {
    await load(companyId: companyId);
    final next = Map<String, dynamic>.from(profiles.value)..remove(profileKey);
    profiles.value = next;
    _pendingKeys.remove(profileKey);
    await _persist();
  }
}
