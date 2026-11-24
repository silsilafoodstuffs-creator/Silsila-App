import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared, short-lived cache for a company's geographic hierarchy.
///
/// Several ERP screens need the same governorate/district/area rows. Keeping
/// one in-flight request and a short TTL avoids downloading the full hierarchy
/// every time the user moves between those screens.
class ErpGeographicDataRepository {
  ErpGeographicDataRepository._();

  static const int _pageSize = 1000;
  static const int _parallelPages = 4;
  static const Duration _cacheTtl = Duration(minutes: 3);

  static final Map<String, _GeoCacheEntry> _cache = <String, _GeoCacheEntry>{};

  static Future<List<Map<String, dynamic>>> fetchActive(
    SupabaseClient client,
    String companyId, {
    bool forceRefresh = false,
  }) async {
    final company = companyId.trim();
    if (company.isEmpty) throw ArgumentError('معرّف الشركة مطلوب للبيانات الجغرافية.');

    final cached = _cache[company];
    if (!forceRefresh && cached != null &&
        cached.expiresAt.isAfter(DateTime.now())) {
      return _copyRows(await cached.future);
    }

    final future = _fetchAll(client, company);
    final entry = _GeoCacheEntry(
      expiresAt: DateTime.now().add(_cacheTtl),
      future: future,
    );
    _cache[company] = entry;

    try {
      final rows = await future;
      if (identical(_cache[company], entry)) {
        _cache[company] = _GeoCacheEntry(
          expiresAt: DateTime.now().add(_cacheTtl),
          future: Future<List<Map<String, dynamic>>>.value(rows),
        );
      }
      return _copyRows(rows);
    } catch (_) {
      if (identical(_cache[company], entry)) _cache.remove(company);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAll(
    SupabaseClient client,
    String companyId,
  ) async {
    // These are the only fields required by party, employee, inventory,
    // and branch selectors. Keep binary/map and administrative metadata out
    // of this shared lookup payload.
    const fields = 'id,parent_id,geo_code,name_ar,name_en,level,is_active';
    final all = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final pages = await Future.wait<List<dynamic>>(
        List.generate(_parallelPages, (index) {
          final start = offset + index * _pageSize;
          return client
              .from('erp_geographic_data')
              .select(fields)
              .eq('company_id', companyId)
              .eq('is_active', true)
              .order('geo_code')
              .range(start, start + _pageSize - 1)
              .then((value) => value as List<dynamic>);
        }),
      );

      for (final page in pages) {
        all.addAll(
          page.map((row) => Map<String, dynamic>.from(row as Map)),
        );
      }

      // Range pages are contiguous and sorted. A short page means no later
      // page can contain additional rows, so the remaining parallel pages
      // from this batch are ignored.
      if (pages.any((page) => page.length < _pageSize)) break;
      offset += _parallelPages * _pageSize;
    }

    return List<Map<String, dynamic>>.unmodifiable(all);
  }

  static List<Map<String, dynamic>> _copyRows(
    List<Map<String, dynamic>> rows,
  ) => rows.map((row) => Map<String, dynamic>.from(row)).toList(growable: false);

  static void invalidate(String companyId) {
    final company = companyId.trim();
    if (company.isNotEmpty) _cache.remove(company);
  }

  static void clear() => _cache.clear();
}

class _GeoCacheEntry {
  const _GeoCacheEntry({
    required this.expiresAt,
    required this.future,
  });

  final DateTime expiresAt;
  final Future<List<Map<String, dynamic>>> future;
}
