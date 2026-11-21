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

  static String _profilesKeyFor(String scope) =>
      scope == 'local' ? storageKey : '${storageKey}__$scope';

  static String _pendingKeyFor(String scope) =>
      scope == 'local' ? pendingStorageKey : '${pendingStorageKey}__$scope';

  static Set<String> get pendingKeys =>
      Set<String>.unmodifiable(_pendingKeys);

  @visibleForTesting
  static void resetForTesting() {
    _loaded = false;
    _activeScope = null;
    _pendingKeys.clear();
    profiles.value = <String, dynamic>{};
  }

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
      final raw = prefs.getString(_profilesKeyFor(scope));
      final decodedProfiles = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decodedProfiles.addAll(Map<String, dynamic>.from(decoded));
        }
      }
      final pending = prefs.getStringList(_pendingKeyFor(scope)) ??
          const <String>[];

      // A different company may have become active while storage was loading.
      // Do not publish stale results into the newly active company's UI state.
      if (_activeScope != scope) return;
      profiles.value = decodedProfiles;
      _pendingKeys
        ..clear()
        ..addAll(pending);
    } finally {
      if (_activeScope == scope) _loaded = true;
    }
  }

  static bool _matchesScope(String? companyId) =>
      _activeScope == scopeForCompany(companyId);

  static void _requireActiveScope(String scope) {
    if (_activeScope != scope) {
      throw StateError('تغيرت الشركة النشطة أثناء تحديث إعدادات تخطيط الشاشات.');
    }
  }

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

  static Future<void> _persist(String scope) async {
    _requireActiveScope(scope);
    // Capture both keys and values before awaiting SharedPreferences so a
    // company switch cannot redirect one tenant's data into another key.
    final profilesKey = _profilesKeyFor(scope);
    final pendingKey = _pendingKeyFor(scope);
    final profilesSnapshot = jsonEncode(
      Map<String, dynamic>.from(profiles.value),
    );
    final pendingSnapshot = _pendingKeys.toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(profilesKey, profilesSnapshot)) {
      throw StateError('تعذر حفظ إعدادات تخطيط الشاشات محلياً.');
    }
    if (!await prefs.setStringList(pendingKey, pendingSnapshot)) {
      throw StateError('تعذر حفظ قائمة التخطيطات المعلقة للمزامنة.');
    }
  }

  static Future<void> save(
    String profileKey,
    Map<String, dynamic> profile, {
    String? companyId,
  }) async {
    final scope = scopeForCompany(companyId);
    await load(companyId: companyId);
    _requireActiveScope(scope);
    final next = Map<String, dynamic>.from(profiles.value)
      ..[profileKey] = Map<String, dynamic>.from(profile);
    profiles.value = next;
    _pendingKeys.add(profileKey);
    await _persist(scope);
  }

  /// Merge remote values without overwriting unsynchronized local edits.
  static Future<void> mergeRemote(
    Map<String, Map<String, dynamic>> remote, {
    String? companyId,
  }) async {
    final scope = scopeForCompany(companyId);
    await load(companyId: companyId);
    _requireActiveScope(scope);
    final next = Map<String, dynamic>.from(profiles.value);
    for (final entry in remote.entries) {
      if (!_pendingKeys.contains(entry.key)) {
        next[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }
    profiles.value = next;
    await _persist(scope);
  }

  static Future<void> markSynced(
    String profileKey, {
    String? companyId,
  }) async {
    final scope = scopeForCompany(companyId);
    await load(companyId: companyId);
    _requireActiveScope(scope);
    _pendingKeys.remove(profileKey);
    await _persist(scope);
  }

  static Future<void> reset(
    String profileKey, {
    String? companyId,
  }) async {
    final scope = scopeForCompany(companyId);
    await load(companyId: companyId);
    _requireActiveScope(scope);
    final next = Map<String, dynamic>.from(profiles.value)..remove(profileKey);
    profiles.value = next;
    _pendingKeys.remove(profileKey);
    await _persist(scope);
  }
}
