import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_keyboard_navigation.dart';
import '../widgets/erp_quick_task_button.dart';
import '../services/erp_workspace_records_service.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ErpActivityTypesScreen extends StatefulWidget {
  const ErpActivityTypesScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpActivityTypesScreen> createState() => _ErpActivityTypesScreenState();
}

class _ErpActivityTypesScreenState extends State<ErpActivityTypesScreen> {
  final _service = ErpWorkspaceRecordsService();
  final List<Map<String, String>> _rows = [];
  String? _selected;
  bool _loading = false, _saving = false, _editing = false;
  String? _message;
  String? _resolvedCompanyId;
  String? get _companyId => (_resolvedCompanyId?.trim().isNotEmpty == true) ? _resolvedCompanyId!.trim() : ((widget.companyId?.trim().isNotEmpty == true) ? widget.companyId!.trim() : null);
  static const _pageKey = 'أنواع الأنشطة';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant ErpActivityTypesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _resolvedCompanyId = null;
      _rows.clear();
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _message = null; });
    try {
      // The dashboard resolves its company asynchronously. Resolve it here too,
      // and reject a stale company ID that is not one of this user's active memberships.
      String? companyId = _companyId;
      final db = Supabase.instance.client;
      final userId = db.auth.currentUser?.id;
      if (userId != null) {
        final memberships = await db
            .from('erp_company_members')
            .select('company_id')
            .eq('user_id', userId)
            .eq('is_active', true)
            .order('created_at');
        final ids = (memberships as List)
            .map((row) => (row['company_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
        if (ids.isNotEmpty && (companyId == null || !ids.contains(companyId))) {
          companyId = ids.first;
        }
      }
      if (companyId == null || companyId.trim().isEmpty) {
        if (mounted) setState(() {
          _rows.clear();
          _message = userId == null
              ? 'سجّل الدخول إلى النظام لعرض أنواع الأنشطة وحفظها.'
              : 'لا توجد شركة نشطة مرتبطة بالمستخدم الحالي.';
        });
        return;
      }
      _resolvedCompanyId = companyId;
      var data = await _service.listPage(companyId: companyId, pageKey: _pageKey);
      // Seed the seven starter activity types in the database, without duplicating
      // or overwriting any records the company has already customized.
      const defaults = <Map<String, String>>[
        {'ترتيب السطر': '1', 'كود النشاط': 'ACT001', 'اسم النشاط عربي': 'مواد غذائية', 'اسم النشاط إنجليزي': 'Foodstuffs', 'نشط': 'true'},
        {'ترتيب السطر': '2', 'كود النشاط': 'ACT002', 'اسم النشاط عربي': 'لوازم بناء', 'اسم النشاط إنجليزي': 'Building Supplies', 'نشط': 'true'},
        {'ترتيب السطر': '3', 'كود النشاط': 'ACT003', 'اسم النشاط عربي': 'ملابس واكسسوارات', 'اسم النشاط إنجليزي': 'Clothing & Accessories', 'نشط': 'true'},
        {'ترتيب السطر': '4', 'كود النشاط': 'ACT004', 'اسم النشاط عربي': 'أجهزة وإلكترونيات', 'اسم النشاط إنجليزي': 'Electronics', 'نشط': 'true'},
        {'ترتيب السطر': '5', 'كود النشاط': 'ACT005', 'اسم النشاط عربي': 'سيارات ومعدات', 'اسم النشاط إنجليزي': 'Vehicles & Equipment', 'نشط': 'true'},
        {'ترتيب السطر': '6', 'كود النشاط': 'ACT006', 'اسم النشاط عربي': 'خدمات شحن ونقل', 'اسم النشاط إنجليزي': 'Shipping & Transport Services', 'نشط': 'true'},
        {'ترتيب السطر': '7', 'كود النشاط': 'ACT007', 'اسم النشاط عربي': 'أثاث وديكورات', 'اسم النشاط إنجليزي': 'Furniture & Decor', 'نشط': 'true'},
      ];
      final existingCodes = data.map((r) => r['كود النشاط']).toSet();
      for (final starter in defaults) {
        if (!existingCodes.contains(starter['كود النشاط'])) {
          await _service.saveRecord(companyId: companyId, pageKey: _pageKey, record: starter);
        }
      }
      if (defaults.any((r) => !existingCodes.contains(r['كود النشاط']))) {
        data = await _service.listPage(companyId: companyId, pageKey: _pageKey);
      }
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(data)
          ..sort((a, b) => (int.tryParse(a['ترتيب السطر'] ?? '') ?? 0)
              .compareTo(int.tryParse(b['ترتيب السطر'] ?? '') ?? 0));
        _message = data.isEmpty ? 'لا توجد أنواع أنشطة محفوظة بعد؛ يمكنك إضافة أول نشاط.' : 'تم تحديث أنواع الأنشطة.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تحميل الأنشطة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _nextActivityCode() {
    var maxCode = 0;
    for (final row in _rows) {
      final match = RegExp(r'^ACT(\\d+)
    final row = <String,String>{
      'ترتيب السطر': (_rows.length + 1).toString(),
      'كود النشاط': code,
      'اسم النشاط عربي': '',
      'اسم النشاط إنجليزي': '',
      'صورة النشاط': '',
      'نشط': 'true',
      '_مسودة': 'true',
    };
    setState(() {
      _editing = true;
      _rows.add(row);
      _selected = code;
      _message = 'تم توليد كود النشاط تلقائيًا. أدخل اسم النشاط ثم اضغط حفظ.';
    });
  }

  void _edit(Map<String,String> r) {
    setState(() {
        _editing = true;
        _selected = r['كود النشاط'];
    });
  }


  Future<void> _save() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا قبل تغيير البيانات.'); return; }
    if ((_companyId ?? '').isEmpty) { setState(() => _message = 'لا توجد شركة نشطة للحفظ.'); return; }
    final rowsToSave = _rows.where((r) => (r['اسم النشاط عربي'] ?? '').trim().isNotEmpty || r['_مسودة'] == 'true').toList();
    if (rowsToSave.isEmpty) { setState(() => _message = 'أضف صفًا وأدخل بياناته قبل الحفظ.'); return; }
    for (final row in rowsToSave) {
      final code = (row['كود النشاط'] ?? '').trim();
      final ar = (row['اسم النشاط عربي'] ?? '').trim();
      if (code.isEmpty || ar.isEmpty) {
        setState(() { _selected = row['كود النشاط']; _message = 'أدخل اسم النشاط العربي؛ كود النشاط يتم توليده تلقائيًا.'; });
        return;
      }
      if (_rows.any((r) => r['كود النشاط'] == code && !identical(r, row) && r['_مرجع داخلي'] != row['_مرجع داخلي'])) {
        setState(() { _selected = code; _message = 'كود النشاط $code مستخدم بالفعل.'; });
        return;
      }
    }
    setState(() => _saving = true);
    try {
      for (final row in rowsToSave) {
        final payload = Map<String,String>.from(row)
          ..remove('_مسودة')
          ..remove('_مرجع داخلي');
        await _service.saveRecord(companyId: _companyId!, pageKey: _pageKey, record: payload);
        // Keep the app activity catalogue synchronized with the ERP master data.
        await Supabase.instance.client.from('activity_types').upsert({
          'code': payload['كود النشاط']!.trim(),
          'name': payload['اسم النشاط عربي']!.trim(),
          'sort_order': int.tryParse(payload['ترتيب السطر'] ?? '') ?? 0,
          'is_active': (payload['نشط'] ?? 'true').toLowerCase() != 'false',
        }, onConflict: 'code');
      }
      await _load();
      if (mounted) setState(() { _editing = false; _message = 'تم حفظ جميع صفوف أنواع الأنشطة في قاعدة البيانات.'; });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحفظ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا قبل حذف البيانات.'); return; }
    final row = _rows.where((r) => r['كود النشاط'] == _selected).firstOrNull;
    if (row == null) { setState(() => _message = 'حدد النشاط المطلوب حذفه أولاً.'); return; }
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('تأكيد الحذف'), content: Text('حذف النشاط: ' + (row['اسم النشاط عربي'] ?? '')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No / لا')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes / نعم، احذف'))]));
    if (yes != true) return;
    try {
      final code = (row['كود النشاط'] ?? '').trim();
      await _service.deleteRecord(companyId: _companyId!, pageKey: _pageKey, recordKey: row['_مرجع داخلي'] ?? code);
      if (code.isNotEmpty) {
        await Supabase.instance.client.from('activity_types').delete().eq('code', code);
      }
      await _load();
      _new();
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحذف: ' + e.toString());
    }
  }

  Widget _task(String text, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: text, icon: icon, onPressed: action, fallbackColor: color, compact: true);

  Future<void> _importExcel() async {
    if (_editing) { setState(() => _message = 'احفظ التعديلات الحالية قبل استيراد Excel.'); return; }
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
      if (picked == null || picked.files.single.bytes == null) return;
      final workbook = excel.Excel.decodeBytes(picked.files.single.bytes!);
      if (workbook.tables.isEmpty) throw StateError('ملف Excel لا يحتوي على ورقة بيانات.');
      final sheet = workbook.tables.values.first;
      if (sheet.rows.isEmpty) throw StateError('ورقة Excel فارغة.');
      final headers = sheet.rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
      final imported = <Map<String, String>>[];
      var nextNumber = int.tryParse(_nextActivityCode().replaceFirst('ACT', '')) ?? 1;
      for (final row in sheet.rows.skip(1)) {
        final values = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          if (headers[i].isNotEmpty) values[headers[i]] = row[i]?.value?.toString() ?? '';
        }
        final name = (values['اسم النشاط عربي'] ?? values['اسم النشاط'] ?? '').trim();
        if (name.isEmpty) continue;
        imported.add({
          'ترتيب السطر': (_rows.length + imported.length + 1).toString(),
          'كود النشاط': 'ACT${nextNumber.toString().padLeft(3, '0')}',
          'اسم النشاط عربي': name,
          'اسم النشاط إنجليزي': (values['اسم النشاط إنجليزي'] ?? '').trim(),
          'نشط': (values['نشط'] ?? 'true').toLowerCase() == 'false' ? 'false' : 'true',
        });
        nextNumber++;
      }
      if (imported.isEmpty) throw StateError('لم يتم العثور على أسماء أنشطة في الملف.');
      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استيراد Excel'),
        content: Text('سيتم إضافة ${imported.length} نشاطًا مع توليد الأكواد تلقائيًا. هل تريد المتابعة؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استيراد'))],
      ));
      if (confirm != true) return;
      for (final row in imported) {
        await _service.saveRecord(companyId: _companyId!, pageKey: _pageKey, record: row);
        await Supabase.instance.client.from('activity_types').upsert({
          'code': row['كود النشاط'], 'name': row['اسم النشاط عربي'],
          'sort_order': int.tryParse(row['ترتيب السطر'] ?? '') ?? 0, 'is_active': row['نشط'] == 'true',
        }, onConflict: 'code');
      }
      await _load();
      if (mounted) setState(() => _message = 'تم استيراد ${imported.length} نشاطًا بنجاح.');
    } catch (e) { if (mounted) setState(() => _message = 'تعذر استيراد Excel: $e'); }
  }

  Future<void> _printPdf() async {
    if (_rows.isEmpty) { setState(() => _message = 'لا توجد بيانات للطباعة.'); return; }
    try {
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      const keys = ['ترتيب السطر', 'كود النشاط', 'اسم النشاط عربي', 'اسم النشاط إنجليزي', 'نشط'];
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(theme: pw.ThemeData.withFont(base: font, bold: font), build: (_) => [
        pw.Text('سلسلة — أنواع الأنشطة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(headers: keys, data: _rows.map((row) => keys.map((key) => row[key] ?? '').toList()).toList()),
      ]));
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
      if (mounted) setState(() => _message = 'تم تجهيز ملف الطباعة / PDF.');
    } catch (e) { if (mounted) setState(() => _message = 'تعذرت الطباعة أو إنشاء PDF: $e'); }
  }
  Future<void> _preview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة أنواع الأنشطة'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _rows.map((r) => ListTile(
                dense: true,
                title: Text('${r['كود النشاط'] ?? ''} — ${r['اسم النشاط عربي'] ?? ''}'),
                subtitle: Text(r['اسم النشاط إنجليزي'] ?? ''),
              )).toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _new, save: _save);
    return Directionality(textDirection: TextDirection.rtl, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: const BoxDecoration(color: Color(0xFF3E007D), borderRadius: BorderRadius.vertical(top: Radius.circular(10))), child: const Row(children: [Icon(Icons.category_outlined, color: Colors.white), SizedBox(width: 8), Text('أنواع الأنشطة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Spacer(), Text('إدارة البرنامج • بيانات أساسية', style: TextStyle(color: Colors.white70, fontSize: 11))])),
      Container(color: Colors.white, padding: const EdgeInsets.all(8), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _task('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
        _task('إضافة', Icons.add_circle_outline, Colors.green, _saving ? null : _new),
        _task('حفظ', Icons.save_outlined, const Color(0xFF3E007D), _saving || !_editing ? null : _save),
        _task('تعديل', Icons.edit_outlined, Colors.orange, _saving || _selected == null ? null : () { final r = _rows.where((x) => x['كود النشاط'] == _selected).firstOrNull; if (r != null) _edit(r); }),
        _task('حذف', Icons.delete_outline, Colors.red, _editing ? _delete : null),
        _task('معاينة', Icons.visibility_outlined, Colors.teal, _preview),
        _task('طباعة', Icons.print_outlined, Colors.blueGrey, () => setState(() => _message = 'تم تجهيز معاينة الطباعة؛ استخدم نافذة المعاينة.')),
        _task('استيراد Excel', Icons.file_upload_outlined, Colors.green.shade800, () => setState(() => _message = 'استيراد Excel لم يُفعّل في هذه الشاشة بعد.')),
        _task('طباعة PDF', Icons.picture_as_pdf_outlined, Colors.red, () => setState(() => _message = 'تصدير PDF لم يُفعّل في هذه الشاشة بعد.')),
      ]))),
      if (_message != null) Container(color: const Color(0xFFF7F2FC), padding: const EdgeInsets.all(7), child: Text(_message!, style: const TextStyle(fontSize: 11, color: Color(0xFF3E007D)))),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE4DDED)), borderRadius: BorderRadius.circular(8)), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowHeight: 57, dataRowMinHeight: 57, dataRowMaxHeight: 57, horizontalMargin: 8, columnSpacing: 14, headingRowColor: WidgetStateProperty.all(const Color(0xFFF1EAF9)), columns: const [DataColumn(label: Text('م (ترتيب السطر)')), DataColumn(label: Text('كود النشاط')), DataColumn(label: Text('اسم النشاط')), DataColumn(label: Text('نشط / غير نشط'))], rows: [
        for (var i = 0; i < _rows.length; i++) DataRow(selected: _rows[i]['كود النشاط'] == _selected, onSelectChanged: (_) => setState(() => _selected = _rows[i]['كود النشاط']), cells: [
          DataCell(SizedBox(width: 38, child: TextFormField(initialValue: _rows[i]['ترتيب السطر'] ?? (i + 1).toString(), key: ValueKey('activity-order-$i'), enabled: _editing, decoration: const InputDecoration(isDense:true,border:InputBorder.none), onChanged: (v) => _rows[i]['ترتيب السطر'] = v))),
          DataCell(SizedBox(width: 130, child: TextFormField(initialValue: _rows[i]['كود النشاط'] ?? '', key: ValueKey('activity-code-$i'), enabled: _editing, decoration: const InputDecoration(isDense:true,border:InputBorder.none), onTap: () => setState(() => _selected = _rows[i]['كود النشاط']), onChanged: (v) { _rows[i]['كود النشاط'] = v; _selected = v; }))),
          DataCell(SizedBox(width: 270, child: TextFormField(initialValue: _rows[i]['اسم النشاط عربي'] ?? '', key: ValueKey('activity-ar-$i'), enabled: _editing, decoration: const InputDecoration(isDense:true,border:InputBorder.none), onTap: () => setState(() => _selected = _rows[i]['كود النشاط']), onChanged: (v) => _rows[i]['اسم النشاط عربي'] = v))),
          DataCell(Checkbox(value: (_rows[i]['نشط'] ?? 'true') == 'true', visualDensity: VisualDensity.compact, onChanged: _editing ? (v) => setState(() => _rows[i]['نشط'] = (v ?? false).toString()) : null)),
        ]),
      ]))),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_rows.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(18), child: Text('لا توجد أنواع أنشطة محفوظة بعد. استخدم «إضافة» لإدخال أول نشاط.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
    ]));
  }
}
, caseSensitive: false).firstMatch((row['كود النشاط'] ?? '').trim());
      final number = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (number > maxCode) maxCode = number;
    }
    return 'ACT${(maxCode + 1).toString().padLeft(3, '0')}';
  }

  void _new() {
    if (_editing) { setState(() => _message = 'احفظ التعديلات الحالية قبل إضافة نشاط جديد.'); return; }
    final code = _nextActivityCode();
    final row = <String,String>{
      'ترتيب السطر': (_rows.length + 1).toString(),
      'كود النشاط': code,
      'اسم النشاط عربي': '',
      'اسم النشاط إنجليزي': '',
      'صورة النشاط': '',
      'نشط': 'true',
      '_مسودة': 'true',
    };
    setState(() {
      _editing = true;
      _rows.add(row);
      _selected = code;
      _message = 'أكمل كود النشاط واسم النشاط داخل صف الجدول، ثم اضغط حفظ.';
    });
  }

  void _edit(Map<String,String> r) {
    setState(() {
        _editing = true;
        _selected = r['كود النشاط'];
    });
  }


  Future<void> _save() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا قبل تغيير البيانات.'); return; }
    if ((_companyId ?? '').isEmpty) { setState(() => _message = 'لا توجد شركة نشطة للحفظ.'); return; }
    final rowsToSave = _rows.where((r) => (r['اسم النشاط عربي'] ?? '').trim().isNotEmpty || r['_مسودة'] == 'true').toList();
    if (rowsToSave.isEmpty) { setState(() => _message = 'أضف صفًا وأدخل بياناته قبل الحفظ.'); return; }
    for (final row in rowsToSave) {
      final code = (row['كود النشاط'] ?? '').trim();
      final ar = (row['اسم النشاط عربي'] ?? '').trim();
      if (code.isEmpty || ar.isEmpty || code.startsWith('NEW-')) {
        setState(() { _selected = row['كود النشاط']; _message = 'أكمل كود النشاط واسمه العربي في كل صف جديد قبل الحفظ.'; });
        return;
      }
      if (_rows.any((r) => r['كود النشاط'] == code && !identical(r, row) && r['_مرجع داخلي'] != row['_مرجع داخلي'])) {
        setState(() { _selected = code; _message = 'كود النشاط $code مستخدم بالفعل.'; });
        return;
      }
    }
    setState(() => _saving = true);
    try {
      for (final row in rowsToSave) {
        final payload = Map<String,String>.from(row)
          ..remove('_مسودة')
          ..remove('_مرجع داخلي');
        await _service.saveRecord(companyId: _companyId!, pageKey: _pageKey, record: payload);
        // Keep the app activity catalogue synchronized with the ERP master data.
        await Supabase.instance.client.from('activity_types').upsert({
          'code': payload['كود النشاط']!.trim(),
          'name': payload['اسم النشاط عربي']!.trim(),
          'sort_order': int.tryParse(payload['ترتيب السطر'] ?? '') ?? 0,
          'is_active': (payload['نشط'] ?? 'true').toLowerCase() != 'false',
        }, onConflict: 'code');
      }
      await _load();
      if (mounted) setState(() { _editing = false; _message = 'تم حفظ جميع صفوف أنواع الأنشطة في قاعدة البيانات.'; });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحفظ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا قبل حذف البيانات.'); return; }
    final row = _rows.where((r) => r['كود النشاط'] == _selected).firstOrNull;
    if (row == null) { setState(() => _message = 'حدد النشاط المطلوب حذفه أولاً.'); return; }
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('تأكيد الحذف'), content: Text('حذف النشاط: ' + (row['اسم النشاط عربي'] ?? '')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No / لا')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes / نعم، احذف'))]));
    if (yes != true) return;
    try {
      final code = (row['كود النشاط'] ?? '').trim();
      await _service.deleteRecord(companyId: _companyId!, pageKey: _pageKey, recordKey: row['_مرجع داخلي'] ?? code);
      if (code.isNotEmpty) {
        await Supabase.instance.client.from('activity_types').delete().eq('code', code);
      }
      await _load();
      _new();
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر الحذف: ' + e.toString());
    }
  }

  Widget _task(String text, IconData icon, Color color, VoidCallback? action) => Padding(padding: const EdgeInsetsDirectional.only(end: 5), child: FilledButton.tonalIcon(onPressed: action, style: FilledButton.styleFrom(foregroundColor: color, backgroundColor: color.withValues(alpha: .10), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8)), icon: Icon(icon, size: 16), label: Text(text, style: const TextStyle(fontSize: 12))));
  Future<void> _preview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة أنواع الأنشطة'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _rows.map((r) => ListTile(
                dense: true,
                title: Text('${r['كود النشاط'] ?? ''} — ${r['اسم النشاط عربي'] ?? ''}'),
                subtitle: Text(r['اسم النشاط إنجليزي'] ?? ''),
              )).toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ErpKeyboardNavigation.registerActions(add: _new, save: _save);
    return Directionality(textDirection: TextDirection.rtl, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: const BoxDecoration(color: Color(0xFF3E007D), borderRadius: BorderRadius.vertical(top: Radius.circular(10))), child: const Row(children: [Icon(Icons.category_outlined, color: Colors.white), SizedBox(width: 8), Text('أنواع الأنشطة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Spacer(), Text('إدارة البرنامج • بيانات أساسية', style: TextStyle(color: Colors.white70, fontSize: 11))])),
      Container(color: Colors.white, padding: const EdgeInsets.all(8), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _task('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
        _task('إضافة', Icons.add_circle_outline, Colors.green, _saving ? null : _new),
        _task('حفظ', Icons.save_outlined, const Color(0xFF3E007D), _saving || !_editing ? null : _save),
        _task('تعديل', Icons.edit_outlined, Colors.orange, _saving || _selected == null ? null : () { final r = _rows.where((x) => x['كود النشاط'] == _selected).firstOrNull; if (r != null) _edit(r); }),
        _task('حذف', Icons.delete_outline, Colors.red, _editing ? _delete : null),
        _task('معاينة', Icons.visibility_outlined, Colors.teal, _preview),
        _task('طباعة', Icons.print_outlined, Colors.blueGrey, () => setState(() => _message = 'تم تجهيز معاينة الطباعة؛ استخدم نافذة المعاينة.')),
        _task('استيراد Excel', Icons.file_upload_outlined, Colors.green.shade800, () => setState(() => _message = 'استيراد Excel لم يُفعّل في هذه الشاشة بعد.')),
        _task('طباعة PDF', Icons.picture_as_pdf_outlined, Colors.red, () => setState(() => _message = 'تصدير PDF لم يُفعّل في هذه الشاشة بعد.')),
      ]))),
      if (_message != null) Container(color: const Color(0xFFF7F2FC), padding: const EdgeInsets.all(7), child: Text(_message!, style: const TextStyle(fontSize: 11, color: Color(0xFF3E007D)))),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE4DDED)), borderRadius: BorderRadius.circular(8)), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowHeight: 57, dataRowMinHeight: 57, dataRowMaxHeight: 57, horizontalMargin: 8, columnSpacing: 14, headingRowColor: WidgetStateProperty.all(const Color(0xFFF1EAF9)), columns: const [DataColumn(label: Text('م (ترتيب السطر)')), DataColumn(label: Text('كود النشاط')), DataColumn(label: Text('اسم النشاط')), DataColumn(label: Text('نشط / غير نشط'))], rows: [
        for (var i = 0; i < _rows.length; i++) DataRow(selected: _rows[i]['كود النشاط'] == _selected, onSelectChanged: (_) => setState(() => _selected = _rows[i]['كود النشاط']), cells: [
          DataCell(SizedBox(width: 38, child: TextFormField(initialValue: _rows[i]['ترتيب السطر'] ?? (i + 1).toString(), key: ValueKey('activity-order-$i'), enabled: _editing, decoration: const InputDecoration(isDense:true,border:InputBorder.none), onChanged: (v) => _rows[i]['ترتيب السطر'] = v))),
          DataCell(SizedBox(width: 130, child: TextFormField(initialValue: _rows[i]['كود النشاط'] ?? '', key: ValueKey('activity-code-$i'), enabled: _editing, decoration: const InputDecoration(isDense:true,border:InputBorder.none), onTap: () => setState(() => _selected = _rows[i]['كود النشاط']), onChanged: (v) { _rows[i]['كود النشاط'] = v; _selected = v; }))),
          DataCell(SizedBox(width: 270, child: TextFormField(initialValue: _rows[i]['اسم النشاط عربي'] ?? '', key: ValueKey('activity-ar-$i'), enabled: _editing, decoration: const InputDecoration(isDense:true,border:InputBorder.none), onTap: () => setState(() => _selected = _rows[i]['كود النشاط']), onChanged: (v) => _rows[i]['اسم النشاط عربي'] = v))),
          DataCell(Checkbox(value: (_rows[i]['نشط'] ?? 'true') == 'true', visualDensity: VisualDensity.compact, onChanged: _editing ? (v) => setState(() => _rows[i]['نشط'] = (v ?? false).toString()) : null)),
        ]),
      ]))),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_rows.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(18), child: Text('لا توجد أنواع أنشطة محفوظة بعد. استخدم «إضافة» لإدخال أول نشاط.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
    ]));
  }
}
