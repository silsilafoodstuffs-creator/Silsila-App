import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'studio_document.dart';

/// Encrypted local-first Studio draft cache isolated by company.
///
/// Drafts created before company scoping existed are kept in the local-only
/// namespace. They are never implicitly uploaded to whichever company happens
/// to be selected later.
class StudioDraftStore {
  static const _legacyKey = 'silsila_studio_drafts_v1';
  static const _legacyFallbackKey = 'silsila_studio_drafts_fallback_v2';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  String _scope(String? companyId) {
    final value = companyId?.trim();
    if (value == null || value.isEmpty) return 'local';
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  String _secureKey(String scope) => 'silsila_studio_drafts_secure_v3_$scope';
  String _fallbackKey(String scope) => 'silsila_studio_drafts_fallback_v3_$scope';

  Future<String?> _readRaw(String scope) async {
    try {
      final secureValue = await _secure.read(key: _secureKey(scope));
      if (secureValue != null && secureValue.isNotEmpty) return secureValue;
    } catch (_) {
      // Continue with the scoped local fallback.
    }
    final prefs = await SharedPreferences.getInstance();
    final fallback = prefs.getString(_fallbackKey(scope));
    if (fallback != null && fallback.isNotEmpty) return fallback;

    // Legacy unscoped data is quarantined in the local-only bucket. Never
    // migrate it into a company namespace because its original owner is unknown.
    if (scope == 'local') {
      for (final legacyKey in [_legacyFallbackKey, _legacyKey]) {
        final legacy = prefs.getString(legacyKey);
        if (legacy == null || legacy.isEmpty) continue;
        try {
          await _secure.write(key: _secureKey('local'), value: legacy);
          await prefs.remove(legacyKey);
        } catch (_) {
          await prefs.setString(_fallbackKey('local'), legacy);
          await prefs.remove(legacyKey);
        }
        return legacy;
      }
    }
    return null;
  }

  Future<void> _writeRaw(String scope, String value) async {
    try {
      await _secure.write(key: _secureKey(scope), value: value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackKey(scope));
      return;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_fallbackKey(scope), value)) {
        throw StateError('تعذر حفظ مسودة الاستوديو محلياً.');
      }
    }
  }

  Future<List<StudioDocument>> list({String? companyId}) async {
    final raw = await _readRaw(_scope(companyId));
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) =>
      StudioDocument.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> save(StudioDocument document, {String? companyId}) async {
    final scope = _scope(companyId);
    final drafts = await list(companyId: companyId);
    final index = drafts.indexWhere((e) => e.id == document.id);
    if (index < 0) {
      drafts.add(document);
    } else {
      drafts[index] = document;
    }
    await _writeRaw(scope, jsonEncode(drafts.map((e) => e.toJson()).toList()));
  }

  Future<void> delete(String id, {String? companyId}) async {
    final scope = _scope(companyId);
    final drafts = await list(companyId: companyId);
    drafts.removeWhere((e) => e.id == id);
    await _writeRaw(scope, jsonEncode(drafts.map((e) => e.toJson()).toList()));
  }
}
