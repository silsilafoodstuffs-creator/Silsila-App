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

  String s(dynamic value) => (value ?? '').toString();

  String label(String level) {
    switch (level) {
      case 'governorate':
        return 'محافظة';
      case 'district':
        return 'حي أو مركز';
      default:
        return 'منطقة أو قرية أو شياخة';
    }
  }

  String childLevel(String level) =>
      level == 'governorate' ? 'district' : 'area';

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
    final companyId = (widget.companyId ?? '').trim();
    if (db == null || companyId.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'لا توجد شركة نشطة محددة. افتح بيانات الشركة ثم أعد تحديث الشاشة.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      message = null;
    });

    try {
      // Supabase/PostgREST commonly caps a response at 1,000 rows.
      // Fetch every page: the geographic tree currently contains more than 6,000 rows,
      // and ordering by geo_code puts EG-AREA rows before governorate roots.
      const pageSize = 1000;
      var offset = 0;
      final allRows = <Map<String, dynamic>>[];
      while (true) {
        final result = await db!
            .from('erp_geographic_data')
            .select(
              'id,parent_id,geo_code,name_ar,name_en,level,is_active,logo_url,'
              'source_name,source_url,latitude,longitude',
            )
            .eq('company_id', companyId)
            .order('geo_code')
            .range(offset, offset + pageSize - 1);
        final page = (result as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        allRows.addAll(page);
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      if (!mounted) return;
      setState(() {
        rows = allRows;
        _rebuildChildren();
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل البيانات الجغرافية: $e';
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
              child: const Text('إلغاء'),
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
      final companyId = (widget.companyId ?? '').trim();
      final data = <String, Object?>{
        'company_id': companyId,
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
            .eq('company_id', companyId);
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
    try {
      await db!
          .from('erp_geographic_data')
          .update({'is_active': row['is_active'] != true})
          .eq('id', row['id'])
          .eq('company_id', (widget.companyId ?? '').trim());
      await load();
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
        title: const Text('حذف بيانات جغرافية'),
        content: Text(
          hasChildren
              ? 'لا يمكن حذف سجل له بيانات تابعة. احذف أو انقل التوابع أولاً.'
              : 'هل تريد حذف «${s(row['name_ar'])}»؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          if (!hasChildren)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
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
          .eq('company_id', (widget.companyId ?? '').trim());
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

  Widget _governorateLogo(Map<String, dynamic> row) {
    final url = s(row['logo_url']);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: CircleAvatar(
        radius: 21,
        backgroundColor: const Color(0xFFF5EFFB),
        child: url.isEmpty
            ? const Icon(Icons.account_balance, color: Color(0xFF3E007D))
            : ClipOval(
                child: Image.network(
                  url,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_balance,
                    color: Color(0xFF3E007D),
                  ),
                ),
              ),
      ),
    );
  }

  Widget node(Map<String, dynamic> row, int depth) {
    final id = s(row['id']);
    final level = s(row['level']);
    final children = _children[id] ?? const <Map<String, dynamic>>[];
    final expanded = _expandedIds.contains(id);

    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 18, bottom: 5),
      child: Card(
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
                          '${s(row['geo_code'])}  •  ${label(level)}',
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
                    IconButton(
                      tooltip: 'إضافة تابع',
                      onPressed: () => edit(parent: id, level: childLevel(level)),
                      icon: const Icon(Icons.add_circle, color: Color(0xFF3E007D)),
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

  @override
  Widget build(BuildContext context) {
    final governorates = rows.where((row) => s(row['level']) == 'governorate').length;
    final districts = rows.where((row) => s(row['level']) == 'district').length;
    final areas = rows.where((row) => s(row['level']) == 'area').length;
    final roots = rows
        .where((row) => s(row['level']) == 'governorate' && s(row['parent_id']).isEmpty)
        .toList();

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
                    'المحافظات ثم الأحياء والمراكز ثم المناطق والقرى والشياخات. افتح كل مستوى لعرض التابعين.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        task('تحديث', Icons.refresh, Colors.blue, loading ? null : load),
                        task(
                          'إضافة محافظة',
                          Icons.add_location_alt,
                          const Color(0xFF168447),
                          () => edit(level: 'governorate'),
                        ),
                        task(
                          'معاينة',
                          Icons.preview_outlined,
                          const Color(0xFFFFA015),
                          () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('معاينة البيانات الجغرافية'),
                              content: Text(
                                'المحافظات: $governorates\n'
                                'الأحياء والمراكز: $districts\n'
                                'المناطق والقرى والشياخات: $areas\n'
                                'إجمالي السجلات: ${rows.length}',
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
          if (loading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'المحافظات: $governorates  •  الأحياء/المراكز: $districts  •  المناطق/القرى: $areas  •  الإجمالي: ${rows.length}',
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
                : ListView(
                    children: roots.map((row) => node(row, 0)).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
