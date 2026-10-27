import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/erp_quick_task_button.dart';

class ErpGeographicDataScreen extends StatefulWidget {
  const ErpGeographicDataScreen({
    super.key,
    required this.companyId,
  });

  final String? companyId;

  @override
  State<ErpGeographicDataScreen> createState() => _ErpGeographicDataScreenState();
}

class _ErpGeographicDataScreenState extends State<ErpGeographicDataScreen> {
  SupabaseClient? db;
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> _children = {};
  final Set<String> _expandedIds = <String>{};
  String? error;
  String? message;
  bool loading = false;
  int _loadGeneration = 0;
  String? _activeCompanyId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _viewMode = 'tree';
  String? _membershipDiagnostic;

  String s(dynamic value) => (value ?? '').toString();

  Uint8List? _decodeLogoBytes(dynamic value) {
    if (value is Uint8List) return value;
    var raw = s(value).trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith(r'\x')) raw = raw.substring(2);
    if (raw.isEmpty || raw.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(raw)) {
      return null;
    }
    final bytes = <int>[];
    for (var i = 0; i < raw.length; i += 2) {
      bytes.add(int.parse(raw.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  Widget _governorateLogo(Map<String, dynamic> row) {
    final bytes = _decodeLogoBytes(row['logo_bytes']);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8C8E8)),
        ),
        child: bytes == null
            ? const Icon(Icons.account_balance_outlined, color: Color(0xFF3E007D), size: 22)
            : Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_balance_outlined,
                  color: Color(0xFF3E007D),
                  size: 22,
                ),
              ),
      ),
    );
  }

  String label(String level, [String? adminType]) {
    if (level == 'district') {
      switch (adminType) {
        case 'markaz':
          return 'مركز';
        case 'qism':
          return 'قسم';
        case 'neighborhood':
          return 'حي';
        case 'city':
          return 'مدينة';
        case 'outlying_area':
          return 'خارج الزمام';
        default:
          return 'وحدة إدارية';
      }
    }
    if (level == 'area') {
      switch (adminType) {
        case 'shiyakha':
          return 'شياخة';
        case 'urban_locality':
          return 'منطقة حضرية (تصنيف مبدئي)';
        case 'rural_locality':
          return 'قرية/منطقة ريفية (تصنيف مبدئي)';
        default:
          return 'منطقة محلية';
      }
    }
    return level == 'governorate' ? 'محافظة' : level;
  }

  String childLevel(String level) =>
      level == 'governorate' ? 'district' : 'area';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    try {
      db = Supabase.instance.client;
    } catch (_) {
      error = 'تعذر الاتصال بقاعدة البيانات.';
    }
    load();
  }

  @override
  void didUpdateWidget(covariant ErpGeographicDataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _expandedIds.clear();
      load();
    }
  }


  void _rebuildChildren() {
    _children.clear();
    for (final row in rows) {
      final parentId = s(row['parent_id']);
      if (parentId.isEmpty) continue;
      (_children[parentId] ??= <Map<String, dynamic>>[]).add(row);
    }
    for (final children in _children.values) {
      children.sort((a, b) => s(a['geo_code']).compareTo(s(b['geo_code'])));
    }
    _expandedIds.removeWhere(
      (id) => !rows.any((row) => s(row['id']) == id),
    );
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    if (db == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر الاتصال بقاعدة البيانات.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      message = null;
    });

    try {
      // Resolve company context from the signed-in user's active memberships.
      // A null/stale dashboard company id must not silently blank this screen.
      final candidates = <String>[];
      final suppliedCompanyId = (widget.companyId ?? '').trim();
      if (suppliedCompanyId.isNotEmpty) candidates.add(suppliedCompanyId);
      final userId = db!.auth.currentUser?.id;
      _membershipDiagnostic = null;
      if (userId != null && userId.isNotEmpty) {
        try {
          final membershipResult = await db!
              .from('erp_company_members')
              .select('company_id')
              .eq('user_id', userId)
              .eq('is_active', true)
              .order('created_at');
          if (!mounted || generation != _loadGeneration) return;
          for (final item in (membershipResult as List)) {
            final id = s((item as Map<String, dynamic>)['company_id']).trim();
            if (id.isNotEmpty && !candidates.contains(id)) candidates.add(id);
          }
        } catch (membershipError) {
          // Keep trying a company explicitly supplied by the dashboard.
          _membershipDiagnostic = 'تعذر قراءة عضوية الشركة: $membershipError';
        }
      }
      if (candidates.isEmpty) {
        throw StateError(
          'لم يتم العثور على شركة نشطة مرتبطة بحساب الدخول. تحقق من عضوية المستخدم.',
        );
      }

      const pageSize = 1000;
      List<Map<String, dynamic>> loadedRows = <Map<String, dynamic>>[];
      String? resolvedCompanyId;
      const fields =
          'id,company_id,parent_id,geo_code,name_ar,name_en,level,is_active,'
          'latitude,longitude,admin_type';

      // Read only rows belonging to a company the signed-in user is linked to.
      // Try all active memberships in case the dashboard passed an old company id.
      String? lastReadError;
      for (final candidateId in candidates) {
        try {
          final candidateRows = <Map<String, dynamic>>[];
          var offset = 0;
          while (true) {
            final result = await db!
                .from('erp_geographic_data')
                .select(fields)
                .eq('company_id', candidateId)
                .order('geo_code')
                .range(offset, offset + pageSize - 1);
            if (!mounted || generation != _loadGeneration) return;
            final page = (result as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            candidateRows.addAll(page);
            if (page.length < pageSize) break;
            offset += pageSize;
          }
          if (candidateRows.isNotEmpty) {
            loadedRows = candidateRows;
            resolvedCompanyId = candidateId;
            break;
          }
        } catch (readError) {
          lastReadError = 'الشركة $candidateId: $readError';
        }
      }

      if (loadedRows.isEmpty) {
        throw StateError(
          'لم تظهر سجلات للشركات المرتبطة. '
          '${lastReadError ?? _membershipDiagnostic ?? 'تحقق من عضوية المستخدم وصلاحيات RLS لجدول erp_geographic_data.'}',
        );
      }

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _activeCompanyId = resolvedCompanyId;
        rows = loadedRows;
        _rebuildChildren();
        // Keep the initial tree compact: show all governorates immediately,
        // expand districts/areas only when the user opens a branch.
        loading = false;
        error = null;
      });
      // Geographic rows intentionally exclude logo bytes. The tree remains fast
      // and uses a neutral emblem until a dedicated, lazy logo viewer is opened.
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل البيانات الجغرافية: $e';
        rows = <Map<String, dynamic>>[];
        _children.clear();
      });
    }
  }

  Future<void> edit({
    Map<String, dynamic>? row,
    String? parent,
    required String level,
  }) async {
    final code = TextEditingController(text: s(row?['geo_code']));
    final arabic = TextEditingController(text: s(row?['name_ar']));
    final english = TextEditingController(text: s(row?['name_en']));
    var active = row?['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(row == null ? 'إضافة ${label(level)}' : 'تعديل ${label(level)}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    decoration: InputDecoration(labelText: 'كود ${label(level)} *'),
                  ),
                  TextField(
                    controller: arabic,
                    decoration: const InputDecoration(labelText: 'الاسم بالعربي *'),
                  ),
                  TextField(
                    controller: english,
                    decoration: const InputDecoration(labelText: 'الاسم بالإنجليزي'),
                  ),
                  CheckboxListTile(
                    value: active,
                    onChanged: (value) => refresh(() => active = value ?? false),
                    title: const Text('نشط'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No / لا'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      code.dispose();
      arabic.dispose();
      english.dispose();
      return;
    }

    try {
      if (code.text.trim().isEmpty || arabic.text.trim().isEmpty) {
        throw ArgumentError('الكود والاسم العربي مطلوبان.');
      }
      final companyId = (_activeCompanyId ?? widget.companyId ?? '').trim();
      final rowCompanyId = s(row?['company_id']).trim();
      final writeCompanyId = row == null ? companyId : rowCompanyId;
      if (writeCompanyId.isEmpty) {
        throw ArgumentError('لا توجد شركة نشطة للحفظ. افتح بيانات الشركة أولاً.');
      }
      final data = <String, Object?>{
        'company_id': writeCompanyId,
        'parent_id': parent,
        'geo_code': code.text.trim(),
        'name_ar': arabic.text.trim(),
        'name_en': english.text.trim().isEmpty ? null : english.text.trim(),
        'level': level,
        'is_active': active,
      };

      if (row == null) {
        await db!.from('erp_geographic_data').insert(data);
      } else {
        await db!
            .from('erp_geographic_data')
            .update(data)
            .eq('id', row['id'])
            .eq('company_id', writeCompanyId);
      }

      if (mounted) {
        setState(() => message = 'تم حفظ البيانات.');
      }
      await load();
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر الحفظ: $e');
    } finally {
      code.dispose();
      arabic.dispose();
      english.dispose();
    }
  }

  Future<void> toggle(Map<String, dynamic> row) async {
    final nextActive = row['is_active'] != true;
    final id = s(row['id']);
    final companyId = s(row['company_id']);
    try {
      await db!
          .from('erp_geographic_data')
          .update({'is_active': nextActive})
          .eq('id', id)
          .eq('company_id', companyId);
      if (!mounted) return;
      // Update the visible row locally instead of reloading all 6k+ geographic
      // records after every checkbox click.
      setState(() {
        final index = rows.indexWhere((item) => s(item['id']) == id);
        if (index >= 0) rows[index]['is_active'] = nextActive;
        error = null;
        message = 'تم تحديث الحالة.';
      });
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر تغيير الحالة: $e');
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final id = s(row['id']);
    final hasChildren = (_children[id] ?? const <Map<String, dynamic>>[]).isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          hasChildren
              ? 'لا يمكن حذف سجل له بيانات تابعة. احذف أو انقل التوابع أولاً.'
              : 'هل ترغب في حذف «${s(row['name_ar'])}»؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No / لا'),
          ),
          if (!hasChildren)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes / نعم، احذف'),
            ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await db!
          .from('erp_geographic_data')
          .delete()
          .eq('id', id)
          .eq('company_id', s(row['company_id']));
      await load();
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر الحذف: $e');
    }
  }

  Widget task(String title, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(
        label: title,
        icon: icon,
        onPressed: action,
        fallbackColor: color,
      );

  Widget node(Map<String, dynamic> row, int depth) {
    final id = s(row['id']);
    final level = s(row['level']);
    final children = _children[id] ?? const <Map<String, dynamic>>[];
    final expanded = _expandedIds.contains(id);

    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 18, bottom: 5),
      child: Card(
        color: level == 'governorate'
            ? const Color(0xFFEDE1F8)
            : level == 'district'
                ? const Color(0xFFFFE4BE)
                : const Color(0xFFFFDDF3),
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            children: [
              Row(
                children: [
                  if (level == 'governorate') _governorateLogo(row),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s(row['name_ar']),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${s(row['geo_code'])}  •  ${label(level, s(row['admin_type']))}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF3E007D),
                          ),
                        ),
                        if (s(row['name_en']).isNotEmpty)
                          Text(
                            s(row['name_en']),
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: row['is_active'] == true,
                    onChanged: (_) => toggle(row),
                    shape: const CircleBorder(),
                  ),
                  if (children.isNotEmpty)
                    IconButton(
                      tooltip: expanded ? 'طي التابعين' : 'عرض التابعين',
                      onPressed: () => setState(() {
                        if (expanded) {
                          _expandedIds.remove(id);
                        } else {
                          _expandedIds.add(id);
                        }
                      }),
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF3E007D),
                      ),
                    ),
                  if (level != 'area')
                    TextButton.icon(
                      onPressed: () => edit(parent: id, level: childLevel(level)),
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: Text(level == 'governorate'
                          ? 'إضافة حي / مركز'
                          : 'إضافة منطقة أو حي'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3E007D),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: () => edit(
                      row: row,
                      parent: s(row['parent_id']).isEmpty ? null : s(row['parent_id']),
                      level: level,
                    ),
                    icon: const Icon(Icons.edit, color: Color(0xFFFFA015)),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: () => remove(row),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                  ),
                ],
              ),
              if (children.isNotEmpty && expanded)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, top: 5),
                  child: Column(
                    children: children.map((item) => node(item, depth + 1)).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridRow(Map<String, dynamic> row) {
    final level = s(row['level']);
    final rowColor = level == 'governorate'
        ? const Color(0xFFEDE1F8)
        : level == 'district'
            ? const Color(0xFFFFE4BE)
            : const Color(0xFFFFDDF3);
    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        border: const Border(bottom: BorderSide(color: Color(0xFFE6DFED))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          if (level == 'governorate') _governorateLogo(row),
          Expanded(
            flex: 3,
            child: Text(s(row['name_ar']), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(flex: 2, child: Text(s(row['geo_code']))),
          Expanded(flex: 2, child: Text(label(level, s(row['admin_type'])))),
          SizedBox(
            width: 82,
            child: Checkbox(
              value: row['is_active'] == true,
              onChanged: (_) => toggle(row),
              shape: const CircleBorder(),
            ),
          ),
          SizedBox(
            width: 90,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'معاينة/تعديل',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => edit(
                    row: row,
                    parent: s(row['parent_id']).isEmpty ? null : s(row['parent_id']),
                    level: level,
                  ),
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFA015), size: 19),
                ),
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => remove(row),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final governorates = rows.where((row) => s(row['level']) == 'governorate').length;
    final districts = rows.where((row) => s(row['level']) == 'district').length;
    final areas = rows.where((row) => s(row['level']) == 'area').length;
    final roots = rows
        .where((row) => s(row['level']) == 'governorate' && s(row['parent_id']).isEmpty)
        .toList();
    final matchedRows = _searchQuery.isEmpty
        ? rows
        : rows.where((row) =>
            s(row['name_ar']).toLowerCase().contains(_searchQuery) ||
            s(row['name_en']).toLowerCase().contains(_searchQuery) ||
            s(row['geo_code']).toLowerCase().contains(_searchQuery)).toList()
          ..sort((a, b) => s(a['geo_code']).compareTo(s(b['geo_code'])));
    final visibleRows = _viewMode == 'tree' && _searchQuery.isEmpty
        ? roots
        : matchedRows;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFF3E007D),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'بيانات جغرافية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'المحافظات ثم المراكز والأقسام ثم القرى والشياخات والمناطق المحلية. افتح كل مستوى لعرض التابعين.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'المصدر الأساسي: Open Admin Data (CC BY 4.0). تمت مراجعة الأسماء المحلية بمصدر مجتمعي؛ والتصنيف الريفي/الحضري لبعض الوحدات مبدئي ويحتاج اعتمادًا رسميًا.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                        task('تحديث', Icons.refresh, Colors.blue, loading ? null : load),
                        task(
                          'إضافة محافظة',
                          Icons.add_location_alt,
                          const Color(0xFF168447),
                          () => edit(level: 'governorate'),
                        ),
                        task(
                          'عرض شجرة',
                          Icons.account_tree_outlined,
                          const Color(0xFF3E007D),
                          () => setState(() => _viewMode = 'tree'),
                        ),
                        task(
                          'عرض جدول',
                          Icons.table_rows_outlined,
                          const Color(0xFF3E007D),
                          () => setState(() => _viewMode = 'grid'),
                        ),
                        task(
                          'معاينة',
                          Icons.preview_outlined,
                          const Color(0xFFFFA015),
                          () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('معاينة البيانات الجغرافية'),
                              content: SizedBox(
                                width: 420,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('المحافظات: $governorates'),
                                    Text('المراكز والأقسام: $districts'),
                                    Text('القرى والشياخات والمناطق المحلية: $areas'),
                                    Text('إجمالي السجلات: ${rows.length}'),
                                    const Divider(),
                                    const Text('المحافظات المحملة', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...roots.take(10).map((item) => Text('${s(item['geo_code'])}  •  ${s(item['name_ar'])}')),
                                    if (roots.length > 10) Text('و${roots.length - 10} محافظة أخرى'),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('إغلاق'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                  ),
                ],
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(message!, style: const TextStyle(color: Colors.green)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                labelText: 'ابحث بكود أو اسم المحافظة أو المركز أو المنطقة',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF3E007D)),
                suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.clear),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'المحافظات: $governorates  •  المراكز/الأقسام: $districts  •  القرى/الشياخات/المناطق: $areas  •  الإجمالي: ${rows.length}',
              style: const TextStyle(
                color: Color(0xFF3E007D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty && !loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            size: 48,
                            color: Color(0xFF9B91A8),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            error ??
                                'لا توجد بيانات جغرافية مسجلة لهذه الشركة. اضغط «تحديث» لإعادة المحاولة.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: loading ? null : load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : visibleRows.isEmpty
                    ? Center(child: Text(_searchQuery.isEmpty ? 'لا توجد محافظات ظاهرة ضمن البيانات المحملة.' : 'لا توجد نتائج مطابقة للبحث.'))
                    : Column(
                        children: [
                          if (_viewMode == 'grid' || _searchQuery.isNotEmpty)
                            Container(
                              color: const Color(0xFFF5EFFB),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: const Row(
                                children: [
                                  Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('الكود', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('المستوى', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 82, child: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                                  SizedBox(width: 90, child: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              key: ValueKey('${_viewMode}-${_searchQuery.isEmpty ? 'all' : _searchQuery}'),
                              itemCount: visibleRows.length,
                              itemBuilder: (context, index) =>
                                  _viewMode == 'tree' && _searchQuery.isEmpty
                                      ? node(visibleRows[index], 0)
                                      : _gridRow(visibleRows[index]),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
