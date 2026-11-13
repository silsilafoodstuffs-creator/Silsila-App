import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'studio_document.dart';

/// Local draft cache. It never writes to ERP business tables.
class StudioDraftStore {
  static const _key = 'silsila_studio_drafts_v1';

  Future<List<StudioDocument>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(drafts.map((e) => e.toJson()).toList());
    if (!await prefs.setString(_key, encoded)) {
      throw StateError('تعذر حفظ مسودة الاستوديو محلياً.');
    }
  }

  Future<void> delete(String id) async {
    final drafts = await list();
    drafts.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(drafts.map((e) => e.toJson()).toList()));
  }
}
