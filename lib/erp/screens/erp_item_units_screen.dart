import 'dart:convert';
import 'package:excel/excel.dart' as excel;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  String? _company, _message, _selectedId;
  String _activityCode = '';
  String _unitPrefix = 'Unt';
  int _unitDigits = 5;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false, _saving = false, _editMode = false;
  static const _purple = Color(0xFF3E007D);
  static const _orange = Color(0xFFFFA015);

  String _s(dynamic v) => (v ?? '').toString();
  List<Map<String, dynamic>> get _activityRows =>
      _rows.where((r) => _s(r['activity_code']) == _activityCode).toList();

  @override
  void initState() {
    super.initState();
    try { _db = Supabase.instance.client; } catch (_) {}
    _load();
  }

  String _nextUnitCode() {
    var maxNumber = 0;
    final pattern = RegExp('^' + RegExp.escape(_unitPrefix) + r'([0-9]+)$', caseSensitive: false);
    for (final row in _rows) {
      final match = pattern.firstMatch(_s(row['unit_code']).trim());
      final number = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (number > maxNumber) maxNumber = number;
    }
    return _unitPrefix + (maxNumber + 1).toString().padLeft(_unitDigits, '0');
  }

  Future<void> _load() async {
    final db = _db;
    if (db == null) { if (mounted) setState(() { _loading = false; _message = 'اتصال قاعدة البيانات غير متاح.'; }); return; }
    if (mounted) setState(() { _loading = true; _message = null; });
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
      final policy = await db.from('erp_program_policies').select('policy_value')
          .eq('company_id', company).eq('policy_key', 'code_generation_registry').maybeSingle();
      if (policy != null) {
        final raw = policy['policy_value'];
        final data = raw is String ? jsonDecode(raw) as Map<String, dynamic> : Map<String, dynamic>.from(raw as Map);
        final types = Map<String, dynamic>.from(data['types'] as Map? ?? {});
        final unit = Map<String, dynamic>.from(types['unit'] as Map? ?? {});
        final prefix = (unit['prefix'] ?? 'Unt').toString();
        final digits = int.tryParse((unit['digits'] ?? 5).toString()) ?? 5;
        if (RegExp(r'^[A-Za-z]{3}
        db.from('activity_types').select('code,name').eq('is_active', true).order('sort_order'),
        db.from('erp_item_unit_catalog')
          .select('id,company_id,activity_code,unit_code,unit_name_ar,unit_name_en,is_active')
          .eq('company_id', company).order('activity_code').order('unit_code'),
      ]);
      if (!mounted) return;
      final activityRows = (results[0] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _company = company;
        _activities = activityRows;
        if (!_activities.any((a) => _s(a['code']) == _activityCode)) {
          _activityCode = _activities.isEmpty ? '' : _s(_activities.first['code']);
        }
        _rows = (results[1] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _selectedId = null;
        _editMode = false;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _message = 'تعذر تحميل وحدات الأصناف: $e'; });
    }
  }

  void _add() {
    if (_activityCode.isEmpty) { setState(() => _message = 'اختر نوع النشاط أولاً.'); return; }
    setState(() {
      _editMode = true;
      final row = <String, dynamic>{
        'id': null, 'company_id': _company, 'activity_code': _activityCode,
        'unit_code': _nextUnitCode(), 'unit_name_ar': '', 'unit_name_en': '',
        'is_active': true, '_draft': true,
      };
      _rows.add(row);
      _selectedId = _s(row['unit_code']);
      _message = 'تم إنشاء كود الوحدة تلقائيًا. أكمل الاسم العربي والإنجليزي ثم اضغط حفظ.';
    });
  }

  Future<void> _save() async {
    final db = _db; final company = _company;
    if (db == null || company == null) return;
    final current = _activityRows;
    final seen = <String>{};
    for (final row in current) {
      final code = _s(row['unit_code']).trim().toUpperCase();
      if (!RegExp('^' + RegExp.escape(_unitPrefix) + r'[0-9]{1,12}$', caseSensitive: false).hasMatch(code)) {
        setState(() => _message = 'كود الوحدة غير صحيح. سيُنشأ تلقائيًا وفق سياسات التكويد.');
        return;
      }
      if (!seen.add(code)) {
        setState(() => _message = 'يوجد كود وحدة مكرر: $code');
        return;
      }
      if (_s(row['unit_name_ar']).trim().isEmpty) {
        setState(() => _message = 'الاسم العربي مطلوب لكل وحدة قبل الحفظ.');
        return;
      }
    }
    setState(() { _saving = true; _message = null; });
    try {
      for (final row in current) {
        final payload = <String, dynamic>{
          'company_id': company, 'activity_code': _activityCode,
          'unit_code': row['_draft'] == true ? '' : _s(row['unit_code']).trim(),
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
      if (mounted) setState(() => _message = 'تم حفظ وحدات النشاط في قاعدة البيانات بنجاح.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeSelected() async {
    final selected = _activityRows.where((r) =>
      _s(r['id']) == (_selectedId ?? '') || _s(r['unit_code']) == (_selectedId ?? '')).toList();
    if (selected.isEmpty) { setState(() => _message = 'حدد الوحدة المراد حذفها أولاً من الجدول.'); return; }
    final row = selected.first;
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('تأكيد حذف الوحدة'),
      content: Text('هل تريد حذف الوحدة «${_s(row['unit_name_ar'])}» — ${_s(row['unit_code'])}؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true), child: const Text('نعم، احذف')),
      ],
    ));
    if (yes != true) return;
    try {
      if (_s(row['id']).isNotEmpty) {
        await _db!.from('erp_item_unit_catalog').delete().eq('id', row['id']).eq('company_id', _company!);
      }
      if (mounted) setState(() {
        _rows.remove(row); _selectedId = null;
        _message = 'تم حذف الوحدة.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر حذف الوحدة: $e');
    }
  }

  void _preview() {
    final rows = _activityRows;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة وحدات النشاط'),
      content: SizedBox(width: 650, child: SingleChildScrollView(child: DataTable(
        columns: const [DataColumn(label: Text('الكود')), DataColumn(label: Text('الوحدة عربي')), DataColumn(label: Text('English')), DataColumn(label: Text('الحالة'))],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(_s(r['unit_code']))), DataCell(Text(_s(r['unit_name_ar']))),
          DataCell(Text(_s(r['unit_name_en']))), DataCell(Text(r['is_active'] == true ? 'نشط' : 'غير نشط')),
        ])).toList(),
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _exportExcel() async {
    try {
      final book = excel.Excel.createExcel();
      final sheet = book['وحدات الأصناف'];
      sheet.appendRow([excel.TextCellValue('م'), excel.TextCellValue('كود الوحدة'), excel.TextCellValue('اسم الوحدة عربي'), excel.TextCellValue('اسم الوحدة إنجليزي'), excel.TextCellValue('الحالة')]);
      final rows = _activityRows;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        sheet.appendRow([
          excel.IntCellValue(i + 1), excel.TextCellValue(_s(r['unit_code'])),
          excel.TextCellValue(_s(r['unit_name_ar'])), excel.TextCellValue(_s(r['unit_name_en'])),
          excel.TextCellValue(r['is_active'] == true ? 'نشط' : 'غير نشط'),
        ]);
      }
      final bytes = book.encode();
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'silsila_item_units_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes), fileExtension: 'xlsx', mimeType: MimeType.microsoftExcel,
      );
      if (mounted) setState(() => _message = 'تم تصدير وحدات النشاط إلى Excel.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تصدير Excel: $e');
    }
  }

  Future<Uint8List> _pdfBytes() async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final doc = pw.Document();
    final rows = _activityRows;
    doc.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text('وحدات الأصناف', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: const ['م', 'كود الوحدة', 'اسم الوحدة عربي', 'اسم الوحدة إنجليزي', 'الحالة'],
          data: rows.asMap().entries.map((e) => [
            e.key + 1, _s(e.value['unit_code']), _s(e.value['unit_name_ar']),
            _s(e.value['unit_name_en']), e.value['is_active'] == true ? 'نشط' : 'غير نشط',
          ]).toList(),
        ),
      ],
    ));
    return doc.save();
  }

  Future<void> _printPdf() async {
    try {
      await Printing.layoutPdf(onLayout: (_) => _pdfBytes());
      if (mounted) setState(() => _message = 'تم فتح معاينة الطباعة.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذرت الطباعة: $e');
    }
  }

  Future<void> _sharePdf() async {
    try {
      await Printing.sharePdf(bytes: await _pdfBytes(), filename: 'silsila_item_units.pdf');
      if (mounted) setState(() => _message = 'تم تجهيز ملف PDF.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر إنشاء PDF: $e');
    }
  }

  Widget _task(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color, compact: true);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: _purple, child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('وحدات الأصناف', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _activities.any((a) => _s(a['code']) == _activityCode) ? _activityCode : null,
            decoration: const InputDecoration(labelText: 'نوع النشاط', filled: true, fillColor: Colors.white),
            items: _activities.map((a) => DropdownMenuItem(value: _s(a['code']), child: Text(_s(a['name'])))).toList(),
            onChanged: _loading || _saving ? null : (value) => setState(() { _activityCode = value ?? ''; _selectedId = null; _message = null; }),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _task('تحديث', Icons.refresh, Colors.blue, _loading || _saving ? null : _load),
            _task('إضافة', Icons.add, Colors.green, _saving ? null : _add),
            _task('حفظ', Icons.save, _orange, _saving || !_editMode ? null : _save),
            _task('تعديل', Icons.edit, Colors.orange, _saving || _activityRows.isEmpty ? null : () => setState(() { _editMode = true; _message = 'وضع التعديل مفعل. عدّل البيانات ثم اضغط حفظ.'; })),
            _task('حذف', Icons.delete_outline, Colors.red, _saving ? null : _removeSelected),
            _task('معاينة', Icons.visibility, const Color(0xFF6E2BA6), _preview),
            _task('طباعة', Icons.print, Colors.pink, _printPdf),
            _task('Excel', Icons.file_download, Colors.green, _exportExcel),
            _task('PDF', Icons.picture_as_pdf, Colors.red, _sharePdf),
          ])),
        ],
      ))),
      if (_message != null) Padding(padding: const EdgeInsets.all(8), child: Text(_message!, style: TextStyle(
        color: _message!.contains('تعذر') || _message!.contains('مطلوب') || _message!.contains('مكرر') ? Colors.red : _purple,
        fontWeight: FontWeight.w700,
      ))),
      if (_loading || _saving) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(
        'عدد الوحدات: ${_activityRows.length} • ${_editMode ? 'وضع التعديل' : 'عرض فقط'} • كود الوحدة تلقائي UNT0001',
        style: const TextStyle(fontWeight: FontWeight.w800),
      )),
      Expanded(child: _activityRows.isEmpty
        ? const Center(child: Text('لا توجد وحدات مسجلة لهذا النشاط. اضغط إضافة لإنشاء أول وحدة.'))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('م')),
              DataColumn(label: Text('كود الوحدة')),
              DataColumn(label: Text('اسم الوحدة عربي')),
              DataColumn(label: Text('اسم الوحدة إنجليزي')),
              DataColumn(label: Text('نشط / غير نشط')),
              DataColumn(label: Text('حذف')),
            ],
            rows: _activityRows.asMap().entries.map((entry) {
              final row = entry.value;
              final key = _s(row['id']).isNotEmpty ? _s(row['id']) : _s(row['unit_code']);
              final selected = key == _selectedId;
              return DataRow(
                selected: selected,
                onSelectChanged: (_) => setState(() => _selectedId = key),
                color: selected ? WidgetStateProperty.all(const Color(0xFFF5EFFB)) : null,
                cells: [
                  DataCell(Text('${entry.key + 1}')),
                  DataCell(SizedBox(width: 115, child: TextFormField(
                    key: ValueKey('unit-code-$key'), initialValue: _s(row['unit_code']), readOnly: true,
                    decoration: const InputDecoration(isDense: true, filled: true, fillColor: Color(0xFFF7F7F7)),
                  ))),
                  DataCell(SizedBox(width: 180, child: TextFormField(
                    key: ValueKey('unit-ar-$key'), initialValue: _s(row['unit_name_ar']), readOnly: !_editMode,
                    onChanged: (v) => row['unit_name_ar'] = v,
                    decoration: const InputDecoration(isDense: true, hintText: 'اسم الوحدة'),
                  ))),
                  DataCell(SizedBox(width: 180, child: TextFormField(
                    key: ValueKey('unit-en-$key'), initialValue: _s(row['unit_name_en']), readOnly: !_editMode,
                    onChanged: (v) => row['unit_name_en'] = v,
                    decoration: const InputDecoration(isDense: true, hintText: 'Unit name'),
                  ))),
                  DataCell(Checkbox(
                    shape: const CircleBorder(), value: row['is_active'] == true,
                    onChanged: !_editMode ? null : (v) => setState(() => row['is_active'] = v ?? false),
                  )),
                  DataCell(IconButton(
                    tooltip: 'حذف الوحدة المحددة', onPressed: () { setState(() => _selectedId = key); _removeSelected(); },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                  )),
                ],
              );
            }).toList(),
          ),
        )),
      ),
    ]),
  );
}
).hasMatch(prefix) && digits >= 1 && digits <= 12) {
          _unitPrefix = prefix;
          _unitDigits = digits;
        }
      }
      final results = await Future.wait([
        db.from('activity_types').select('code,name').eq('is_active', true).order('sort_order'),
        db.from('erp_item_unit_catalog')
          .select('id,company_id,activity_code,unit_code,unit_name_ar,unit_name_en,is_active')
          .eq('company_id', company).order('activity_code').order('unit_code'),
      ]);
      if (!mounted) return;
      final activityRows = (results[0] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _company = company;
        _activities = activityRows;
        if (!_activities.any((a) => _s(a['code']) == _activityCode)) {
          _activityCode = _activities.isEmpty ? '' : _s(_activities.first['code']);
        }
        _rows = (results[1] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _selectedId = null;
        _editMode = false;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _message = 'تعذر تحميل وحدات الأصناف: $e'; });
    }
  }

  void _add() {
    if (_activityCode.isEmpty) { setState(() => _message = 'اختر نوع النشاط أولاً.'); return; }
    setState(() {
      _editMode = true;
      final row = <String, dynamic>{
        'id': null, 'company_id': _company, 'activity_code': _activityCode,
        'unit_code': _nextUnitCode(), 'unit_name_ar': '', 'unit_name_en': '',
        'is_active': true, '_draft': true,
      };
      _rows.add(row);
      _selectedId = _s(row['unit_code']);
      _message = 'تم إنشاء كود الوحدة تلقائيًا. أكمل الاسم العربي والإنجليزي ثم اضغط حفظ.';
    });
  }

  Future<void> _save() async {
    final db = _db; final company = _company;
    if (db == null || company == null) return;
    final current = _activityRows;
    final seen = <String>{};
    for (final row in current) {
      final code = _s(row['unit_code']).trim().toUpperCase();
      if (!RegExp(r'^UNT[0-9]{4,}$').hasMatch(code)) {
        setState(() => _message = 'كود الوحدة غير صحيح. استخدم التكويد التلقائي UNT0001 وما يليه.');
        return;
      }
      if (!seen.add(code)) {
        setState(() => _message = 'يوجد كود وحدة مكرر: $code');
        return;
      }
      if (_s(row['unit_name_ar']).trim().isEmpty) {
        setState(() => _message = 'الاسم العربي مطلوب لكل وحدة قبل الحفظ.');
        return;
      }
    }
    setState(() { _saving = true; _message = null; });
    try {
      for (final row in current) {
        final payload = <String, dynamic>{
          'company_id': company, 'activity_code': _activityCode,
          'unit_code': _s(row['unit_code']).trim().toUpperCase(),
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
      if (mounted) setState(() => _message = 'تم حفظ وحدات النشاط في قاعدة البيانات بنجاح.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeSelected() async {
    final selected = _activityRows.where((r) =>
      _s(r['id']) == (_selectedId ?? '') || _s(r['unit_code']) == (_selectedId ?? '')).toList();
    if (selected.isEmpty) { setState(() => _message = 'حدد الوحدة المراد حذفها أولاً من الجدول.'); return; }
    final row = selected.first;
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('تأكيد حذف الوحدة'),
      content: Text('هل تريد حذف الوحدة «${_s(row['unit_name_ar'])}» — ${_s(row['unit_code'])}؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true), child: const Text('نعم، احذف')),
      ],
    ));
    if (yes != true) return;
    try {
      if (_s(row['id']).isNotEmpty) {
        await _db!.from('erp_item_unit_catalog').delete().eq('id', row['id']).eq('company_id', _company!);
      }
      if (mounted) setState(() {
        _rows.remove(row); _selectedId = null;
        _message = 'تم حذف الوحدة.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر حذف الوحدة: $e');
    }
  }

  void _preview() {
    final rows = _activityRows;
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة وحدات النشاط'),
      content: SizedBox(width: 650, child: SingleChildScrollView(child: DataTable(
        columns: const [DataColumn(label: Text('الكود')), DataColumn(label: Text('الوحدة عربي')), DataColumn(label: Text('English')), DataColumn(label: Text('الحالة'))],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Text(_s(r['unit_code']))), DataCell(Text(_s(r['unit_name_ar']))),
          DataCell(Text(_s(r['unit_name_en']))), DataCell(Text(r['is_active'] == true ? 'نشط' : 'غير نشط')),
        ])).toList(),
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _exportExcel() async {
    try {
      final book = excel.Excel.createExcel();
      final sheet = book['وحدات الأصناف'];
      sheet.appendRow([excel.TextCellValue('م'), excel.TextCellValue('كود الوحدة'), excel.TextCellValue('اسم الوحدة عربي'), excel.TextCellValue('اسم الوحدة إنجليزي'), excel.TextCellValue('الحالة')]);
      final rows = _activityRows;
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        sheet.appendRow([
          excel.IntCellValue(i + 1), excel.TextCellValue(_s(r['unit_code'])),
          excel.TextCellValue(_s(r['unit_name_ar'])), excel.TextCellValue(_s(r['unit_name_en'])),
          excel.TextCellValue(r['is_active'] == true ? 'نشط' : 'غير نشط'),
        ]);
      }
      final bytes = book.encode();
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'silsila_item_units_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes), fileExtension: 'xlsx', mimeType: MimeType.microsoftExcel,
      );
      if (mounted) setState(() => _message = 'تم تصدير وحدات النشاط إلى Excel.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تصدير Excel: $e');
    }
  }

  Future<Uint8List> _pdfBytes() async {
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final doc = pw.Document();
    final rows = _activityRows;
    doc.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font, bold: font),
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text('وحدات الأصناف', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: const ['م', 'كود الوحدة', 'اسم الوحدة عربي', 'اسم الوحدة إنجليزي', 'الحالة'],
          data: rows.asMap().entries.map((e) => [
            e.key + 1, _s(e.value['unit_code']), _s(e.value['unit_name_ar']),
            _s(e.value['unit_name_en']), e.value['is_active'] == true ? 'نشط' : 'غير نشط',
          ]).toList(),
        ),
      ],
    ));
    return doc.save();
  }

  Future<void> _printPdf() async {
    try {
      await Printing.layoutPdf(onLayout: (_) => _pdfBytes());
      if (mounted) setState(() => _message = 'تم فتح معاينة الطباعة.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذرت الطباعة: $e');
    }
  }

  Future<void> _sharePdf() async {
    try {
      await Printing.sharePdf(bytes: await _pdfBytes(), filename: 'silsila_item_units.pdf');
      if (mounted) setState(() => _message = 'تم تجهيز ملف PDF.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر إنشاء PDF: $e');
    }
  }

  Widget _task(String label, IconData icon, Color color, VoidCallback? action) =>
    ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color, compact: true);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(color: _purple, child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('وحدات الأصناف', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _activities.any((a) => _s(a['code']) == _activityCode) ? _activityCode : null,
            decoration: const InputDecoration(labelText: 'نوع النشاط', filled: true, fillColor: Colors.white),
            items: _activities.map((a) => DropdownMenuItem(value: _s(a['code']), child: Text(_s(a['name'])))).toList(),
            onChanged: _loading || _saving ? null : (value) => setState(() { _activityCode = value ?? ''; _selectedId = null; _message = null; }),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _task('تحديث', Icons.refresh, Colors.blue, _loading || _saving ? null : _load),
            _task('إضافة', Icons.add, Colors.green, _saving ? null : _add),
            _task('حفظ', Icons.save, _orange, _saving || !_editMode ? null : _save),
            _task('تعديل', Icons.edit, Colors.orange, _saving || _activityRows.isEmpty ? null : () => setState(() { _editMode = true; _message = 'وضع التعديل مفعل. عدّل البيانات ثم اضغط حفظ.'; })),
            _task('حذف', Icons.delete_outline, Colors.red, _saving ? null : _removeSelected),
            _task('معاينة', Icons.visibility, const Color(0xFF6E2BA6), _preview),
            _task('طباعة', Icons.print, Colors.pink, _printPdf),
            _task('Excel', Icons.file_download, Colors.green, _exportExcel),
            _task('PDF', Icons.picture_as_pdf, Colors.red, _sharePdf),
          ])),
        ],
      ))),
      if (_message != null) Padding(padding: const EdgeInsets.all(8), child: Text(_message!, style: TextStyle(
        color: _message!.contains('تعذر') || _message!.contains('مطلوب') || _message!.contains('مكرر') ? Colors.red : _purple,
        fontWeight: FontWeight.w700,
      ))),
      if (_loading || _saving) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(
        'عدد الوحدات: ${_activityRows.length} • ${_editMode ? 'وضع التعديل' : 'عرض فقط'} • كود الوحدة تلقائي UNT0001',
        style: const TextStyle(fontWeight: FontWeight.w800),
      )),
      Expanded(child: _activityRows.isEmpty
        ? const Center(child: Text('لا توجد وحدات مسجلة لهذا النشاط. اضغط إضافة لإنشاء أول وحدة.'))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('م')),
              DataColumn(label: Text('كود الوحدة')),
              DataColumn(label: Text('اسم الوحدة عربي')),
              DataColumn(label: Text('اسم الوحدة إنجليزي')),
              DataColumn(label: Text('نشط / غير نشط')),
              DataColumn(label: Text('حذف')),
            ],
            rows: _activityRows.asMap().entries.map((entry) {
              final row = entry.value;
              final key = _s(row['id']).isNotEmpty ? _s(row['id']) : _s(row['unit_code']);
              final selected = key == _selectedId;
              return DataRow(
                selected: selected,
                onSelectChanged: (_) => setState(() => _selectedId = key),
                color: selected ? WidgetStateProperty.all(const Color(0xFFF5EFFB)) : null,
                cells: [
                  DataCell(Text('${entry.key + 1}')),
                  DataCell(SizedBox(width: 115, child: TextFormField(
                    key: ValueKey('unit-code-$key'), initialValue: _s(row['unit_code']), readOnly: true,
                    decoration: const InputDecoration(isDense: true, filled: true, fillColor: Color(0xFFF7F7F7)),
                  ))),
                  DataCell(SizedBox(width: 180, child: TextFormField(
                    key: ValueKey('unit-ar-$key'), initialValue: _s(row['unit_name_ar']), readOnly: !_editMode,
                    onChanged: (v) => row['unit_name_ar'] = v,
                    decoration: const InputDecoration(isDense: true, hintText: 'اسم الوحدة'),
                  ))),
                  DataCell(SizedBox(width: 180, child: TextFormField(
                    key: ValueKey('unit-en-$key'), initialValue: _s(row['unit_name_en']), readOnly: !_editMode,
                    onChanged: (v) => row['unit_name_en'] = v,
                    decoration: const InputDecoration(isDense: true, hintText: 'Unit name'),
                  ))),
                  DataCell(Checkbox(
                    shape: const CircleBorder(), value: row['is_active'] == true,
                    onChanged: !_editMode ? null : (v) => setState(() => row['is_active'] = v ?? false),
                  )),
                  DataCell(IconButton(
                    tooltip: 'حذف الوحدة المحددة', onPressed: () { setState(() => _selectedId = key); _removeSelected(); },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                  )),
                ],
              );
            }).toList(),
          ),
        )),
      ),
    ]),
  );
}
