import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';

class ErpItemUnitsScreen extends StatefulWidget {
  const ErpItemUnitsScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpItemUnitsScreen> createState() => _ErpItemUnitsScreenState();
}

class _ErpItemUnitsScreenState extends State<ErpItemUnitsScreen> {
  SupabaseClient? _db;
  String? _company, _message;
  String _activityCode = '';
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false, _saving = false;
  static const _purple = Color(0xFF3E007D);
  static const _orange = Color(0xFFFFA015);

  String _s(dynamic v) => (v ?? '').toString();
  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) { setState(() { _message = 'اتصال قاعدة البيانات غير متاح.'; }); return; }
    setState(() { _loading = true; _message = null; });
    try {
      var company = (widget.companyId ?? '').trim();
      final uid = db.auth.currentUser?.id;
      if (uid != null) {
        final memberships = await db.from('erp_company_members').select('company_id')
          .eq('user_id', uid).eq('is_active', true).order('created_at');
        final ids = (memberships as List).map((e) => _s(e['company_id'])).toList();
        if (company.isEmpty || !ids.contains(company)) company = ids.isEmpty ? '' : ids.first;
      }
      if (company.isEmpty) throw StateError('لا توجد شركة نشطة مرتبطة بالمستخدم.');
      final activities = await db.from('activity_types').select('code,name')
        .eq('is_active', true).order('sort_order');
      final units = await db.from('erp_item_unit_catalog')
        .select('id,company_id,activity_code,unit_code,unit_name_ar,unit_name_en,is_active')
        .eq('company_id', company).order('unit_code');
      if (!mounted) return;
      final activityRows = (activities as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _company = company;
        _activities = activityRows;
        if (!_activities.any((a) => _s(a['code']) == _activityCode)) {
          _activityCode = _activities.isEmpty ? '' : _s(_activities.first['code']);
        }
        _rows = (units as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _message = 'تعذر تحميل وحدات الأصناف: $e'; });
    }
  }

  void _add() {
    if (_activityCode.isEmpty) { setState(() => _message = 'اختر نوع النشاط أولاً.'); return; }
    setState(() {
      _rows.add({'id': null, 'company_id': _company, 'activity_code': _activityCode,
        'unit_code': '', 'unit_name_ar': '', 'unit_name_en': '', 'is_active': true, '_draft': true});
      _message = null;
    });
  }

  Future<void> _save() async {
    final db = _db; final company = _company;
    if (db == null || company == null) return;
    final current = _rows.where((r) => _s(r['activity_code']) == _activityCode).toList();
    for (final row in current) {
      if (_s(row['unit_code']).trim().isEmpty || _s(row['unit_name_ar']).trim().isEmpty) {
        setState(() => _message = 'كود الوحدة والاسم العربي مطلوبان لكل سطر قبل الحفظ.');
        return;
      }
    }
    setState(() { _saving = true; _message = null; });
    try {
      for (final row in current) {
        final payload = <String, dynamic>{
          'company_id': company, 'activity_code': _activityCode,
          'unit_code': _s(row['unit_code']).trim(),
          'unit_name_ar': _s(row['unit_name_ar']).trim(),
          'unit_name_en': _s(row['unit_name_en']).trim().isEmpty ? null : _s(row['unit_name_en']).trim(),
          'is_active': row['is_active'] == true,
        };
        if (_s(row['id']).isNotEmpty) {
          await db.from('erp_item_unit_catalog').update(payload).eq('id', row['id']).eq('company_id', company);
        } else {
          await db.from('erp_item_unit_catalog').insert(payload);
        }
      }
      await _load();
      if (mounted) setState(() => _message = 'تم حفظ وحدات النشاط في قاعدة البيانات.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final db = _db; final company = _company;
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('حذف الوحدة'),
      content: Text('هل تريد حذف «${_s(row['unit_name_ar'])}»؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No / لا')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true), child: const Text('Yes / نعم، احذف الوحدة')),
      ],
    ));
    if (yes != true) return;
    try {
      if (_s(row['id']).isNotEmpty && db != null && company != null) {
        await db.from('erp_item_unit_catalog').delete().eq('id', row['id']).eq('company_id', company);
      }
      if (mounted) setState(() { _rows.remove(row); _message = 'تم حذف الوحدة.'; });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر حذف الوحدة: $e');
    }
  }

  Widget _task(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: _purple, child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('وحدات الأصناف', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          DropdownButtonFormField<String>(
            value: _activities.any((a) => _s(a['code']) == _activityCode) ? _activityCode : null,
            decoration: const InputDecoration(labelText: 'نوع النشاط', filled: true, fillColor: Colors.white),
            items: _activities.map((a) => DropdownMenuItem(value: _s(a['code']), child: Text(_s(a['name'])))).toList(),
            onChanged: (value) => setState(() { _activityCode = value ?? ''; _message = null; }),
          ),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _task('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _task('إضافة', Icons.add, Colors.green, _add),
            _task('حفظ', Icons.save, _orange, _saving ? null : _save),
          ])),
        ],
      ))),
      if (_message != null) Padding(padding: const EdgeInsets.all(8), child: Text(_message!)),
      if (_loading) const LinearProgressIndicator(),
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('م')),
            DataColumn(label: Text('كود الوحدة')),
            DataColumn(label: Text('اسم الوحدة عربي')),
            DataColumn(label: Text('اسم الوحدة إنجليزي')),
            DataColumn(label: Text('نشط')),
            DataColumn(label: Text('حذف')),
          ],
          rows: _rows.where((r) => _s(r['activity_code']) == _activityCode).toList().asMap().entries.map((entry) {
            final row = entry.value;
            return DataRow(cells: [
              DataCell(Text('${entry.key + 1}')),
              DataCell(SizedBox(width: 120, child: TextFormField(initialValue: _s(row['unit_code']),
                onChanged: (v) => row['unit_code'] = v, decoration: const InputDecoration(isDense: true)))),
              DataCell(SizedBox(width: 180, child: TextFormField(initialValue: _s(row['unit_name_ar']),
                onChanged: (v) => row['unit_name_ar'] = v, decoration: const InputDecoration(isDense: true)))),
              DataCell(SizedBox(width: 180, child: TextFormField(initialValue: _s(row['unit_name_en']),
                onChanged: (v) => row['unit_name_en'] = v, decoration: const InputDecoration(isDense: true)))),
              DataCell(Checkbox(shape: const CircleBorder(), value: row['is_active'] == true,
                onChanged: (v) => setState(() => row['is_active'] = v ?? false))),
              DataCell(IconButton(tooltip: 'حذف الوحدة', onPressed: () => _remove(row),
                icon: const Icon(Icons.delete_forever, color: Colors.red))),
            ]);
          }).toList(),
        ),
      ))),
    ]),
  );
}
