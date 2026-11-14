import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'studio_document.dart';

/// Encrypted local-first Studio draft cache with a SharedPreferences fallback.
class StudioDraftStore {
  static const _key = 'silsila_studio_drafts_secure_v2';
  static const _legacyKey = 'silsila_studio_drafts_v1';
  static const _fallbackKey = 'silsila_studio_drafts_fallback_v2';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  Future<String?> _readRaw() async {
    try {
      final secureValue = await _secure.read(key: _key);
      if (secureValue != null && secureValue.isNotEmpty) return secureValue;
    } catch (_) {
      // Continue with the local fallback when platform secure storage is unavailable.
    }
    final prefs = await SharedPreferences.getInstance();
    final fallback = prefs.getString(_fallbackKey);
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secure.write(key: _key, value: legacy);
        await prefs.remove(_legacyKey);
        return legacy;
      } catch (_) {
        await prefs.setString(_fallbackKey, legacy);
        return legacy;
      }
    }
    return null;
  }

  Future<void> _writeRaw(String value) async {
    try {
      await _secure.write(key: _key, value: value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackKey);
      await prefs.remove(_legacyKey);
      return;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_fallbackKey, value)) {
        throw StateError('تعذر حفظ مسودة الاستوديو محلياً.');
      }
    }
  }

  Future<List<StudioDocument>> list() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) =>
      StudioDocument.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> save(StudioDocument document) async {
    final drafts = await list();
    final index = drafts.indexWhere((e) => e.id == document.id);
    if (index < 0) {
      drafts.add(document);
    } else {
      drafts[index] = document;
    }
    await _writeRaw(jsonEncode(drafts.map((e) => e.toJson()).toList()));
  }

  Future<void> delete(String id) async {
    final drafts = await list();
    drafts.removeWhere((e) => e.id == id);
    await _writeRaw(jsonEncode(drafts.map((e) => e.toJson()).toList()));
  }
}
