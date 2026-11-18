import 'package:flutter/material.dart';
import '../services/erp_print_support.dart';
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
      _normalizeActivityCodes(data);
      // The shared activity master is the authoritative display source. Workspace
      // rows remain the editable company-specific overlay, but an empty or
      // restricted workspace query must not hide globally active activities.
      final masterRows = await db
          .from('activity_types')
          .select('code,name,name_en,sort_order,is_active,show_in_app')
          .eq('is_active', true)
          .eq('show_in_app', true)
          .order('sort_order');
      final workspaceByCode = <String, Map<String, String>>{
        for (final row in data)
          if ((row['كود النشاط'] ?? '').trim().isNotEmpty)
            row['كود النشاط']!.trim().toUpperCase(): row,
      };
      final mergedByCode = <String, Map<String, String>>{};
      for (final raw in (masterRows as List)) {
        final master = Map<String, dynamic>.from(raw as Map);
        final code = (master['code'] ?? '').toString().trim().toUpperCase();
        if (code.isEmpty) continue;
        final workspace = workspaceByCode[code];
        mergedByCode[code] = <String, String>{
          'ترتيب السطر': workspace?['ترتيب السطر'] ?? (master['sort_order'] ?? '').toString(),
          'كود النشاط': code,
          'اسم النشاط عربي': (workspace?['اسم النشاط عربي']?.trim().isNotEmpty == true)
              ? workspace!['اسم النشاط عربي']!
              : (master['name'] ?? '').toString(),
          'اسم النشاط إنجليزي': (workspace?['اسم النشاط إنجليزي']?.trim().isNotEmpty == true)
              ? workspace!['اسم النشاط إنجليزي']!
              : (master['name_en'] ?? '').toString(),
          'نشط': 'true',
          'يظهر في التطبيق': 'true',
          '_مرجع داخلي': workspace?['_مرجع داخلي'] ?? code,
        };
      }
      for (final entry in workspaceByCode.entries) {
        mergedByCode.putIfAbsent(entry.key, () => entry.value);
      }
      data = mergedByCode.values.toList();
      _normalizeActivityCodes(data);
      // Keep the activity master on the same canonical 01..20 codes as the
      // ERP item-category tree; retain any existing customized labels.
      const defaults = <Map<String, String>>[
        {'ترتيب السطر':'1','كود النشاط':'01','اسم النشاط عربي':'مواد غذائية','اسم النشاط إنجليزي':'Foodstuffs','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'2','كود النشاط':'02','اسم النشاط عربي':'لوازم بناء','اسم النشاط إنجليزي':'Building Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'3','كود النشاط':'03','اسم النشاط عربي':'ملابس واكسسوارات','اسم النشاط إنجليزي':'Clothing & Accessories','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'4','كود النشاط':'04','اسم النشاط عربي':'أجهزة وإلكترونيات','اسم النشاط إنجليزي':'Electronics','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'5','كود النشاط':'05','اسم النشاط عربي':'سيارات ومعدات','اسم النشاط إنجليزي':'Vehicles & Equipment','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'6','كود النشاط':'06','اسم النشاط عربي':'خدمات شحن ونقل','اسم النشاط إنجليزي':'Shipping & Transport Services','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'7','كود النشاط':'07','اسم النشاط عربي':'أثاث وديكورات','اسم النشاط إنجليزي':'Furniture & Decor','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'8','كود النشاط':'08','اسم النشاط عربي':'أدوات كهربائية','اسم النشاط إنجليزي':'Electrical Tools','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'9','كود النشاط':'09','اسم النشاط عربي':'مكتبات وقرطاسية','اسم النشاط إنجليزي':'Stationery & Office Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'10','كود النشاط':'10','اسم النشاط عربي':'مستلزمات طبية','اسم النشاط إنجليزي':'Medical Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'11','كود النشاط':'11','اسم النشاط عربي':'مستحضرات تجميل وعناية','اسم النشاط إنجليزي':'Beauty & Personal Care','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'12','كود النشاط':'12','اسم النشاط عربي':'زراعة ومستلزمات زراعية','اسم النشاط إنجليزي':'Agriculture Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'13','كود النشاط':'13','اسم النشاط عربي':'قطع غيار ومستلزمات صيانة','اسم النشاط إنجليزي':'Spare Parts & Maintenance','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'14','كود النشاط':'14','اسم النشاط عربي':'مستلزمات فندقية ومطاعم','اسم النشاط إنجليزي':'Hospitality & Restaurant Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'15','كود النشاط':'15','اسم النشاط عربي':'تعبئة وتغليف','اسم النشاط إنجليزي':'Packaging Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'16','كود النشاط':'16','اسم النشاط عربي':'منظفات ومستلزمات نظافة','اسم النشاط إنجليزي':'Cleaning Supplies','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'17','كود النشاط':'17','اسم النشاط عربي':'مستلزمات حيوانات وأعلاف','اسم النشاط إنجليزي':'Pet Supplies & Feed','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'18','كود النشاط':'18','اسم النشاط عربي':'خدمات نقل وتوصيل','اسم النشاط إنجليزي':'Transport & Delivery Services','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'19','كود النشاط':'19','اسم النشاط عربي':'أنشطة أخرى','اسم النشاط إنجليزي':'Other Activities','نشط':'true','يظهر في التطبيق':'true'},
        {'ترتيب السطر':'20','كود النشاط':'20','اسم النشاط عربي':'كتب ومطبوعات','اسم النشاط إنجليزي':'Books & Publications','نشط':'true','يظهر في التطبيق':'true'},
      ];
      final existingCodes = data.map((r) => r['كود النشاط']).toSet();
      for (final starter in defaults) {
        if (!existingCodes.contains(starter['كود النشاط'])) {
          await _service.saveRecord(companyId: companyId, pageKey: _pageKey, record: starter);
        }
      }
      if (defaults.any((r) => !existingCodes.contains(r['كود النشاط']))) {
        data = await _service.listPage(companyId: companyId, pageKey: _pageKey);
        _normalizeActivityCodes(data);
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

  void _normalizeActivityCodes(List<Map<String, String>> rows) {
    for (final row in rows) {
      final raw = (row['كود النشاط'] ?? '').trim().toUpperCase();
      if (raw.startsWith('ACT') && raw.length == 6) {
        final number = int.tryParse(raw.substring(3));
        if (number != null) row['كود النشاط'] = number.toString().padLeft(2, '0');
      } else if (RegExp(r'^[0-9]{1,2}$').hasMatch(raw)) {
        row['كود النشاط'] = int.parse(raw).toString().padLeft(2, '0');
      }
    }
  }

  String _nextActivityCode() {
    var maxCode = 0;
    for (final row in _rows) {
      final code = (row['كود النشاط'] ?? '').trim().toUpperCase();
      final number = code.startsWith('ACT')
          ? int.tryParse(code.substring(3)) ?? 0
          : int.tryParse(code) ?? 0;
      if (number > maxCode) maxCode = number;
    }
    return (maxCode + 1).toString().padLeft(2, '0');
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
      'يظهر في التطبيق': 'true',
      '_مسودة': 'true',
    };
    setState(() {
      _editing = true;
      _rows.add(row);
      _selected = code;
      _message = 'تم توليد كود النشاط تلقائيًا. أدخل اسم النشاط ثم اضغط حفظ.';
    });
  }

  void _editAll() {
    if (_rows.isEmpty) { setState(() => _message = 'لا توجد صفوف لتعديلها.'); return; }
    setState(() { _editing = true; _message = 'وضع تعديل الجريد بالكامل مفعل؛ عدّل أي صف مسموح لك به ثم اضغط حفظ.'; });
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
        setState(() { _selected = row['كود النشاط']; _message = 'أدخل اسم النشاط العربي؛ كود النشاط يُولّد تلقائيًا ولا يمكن تعديله.'; });
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
          'name_en': (payload['اسم النشاط إنجليزي'] ?? '').trim(),
          'show_in_app': (payload['نشط'] ?? 'true').toLowerCase() != 'false' && (payload['يظهر في التطبيق'] ?? 'true').toLowerCase() != 'false',
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

  Future<bool> _confirmActivityDelete({required String title, required String message}) async {
    final answer = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(message),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، احذف'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء الأمر')),
      ],
    ));
    return answer == true;
  }

  Future<void> _deleteActivityRow(Map<String, String> row) async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا، وتأكد من صلاحية الحذف.'); return; }
    final code = (row['كود النشاط'] ?? '').trim();
    final name = (row['اسم النشاط عربي'] ?? code).trim();
    if (code.isEmpty || (_companyId ?? '').isEmpty) {
      setState(() => _message = 'لا يمكن حذف هذا الصف لعدم اكتمال مرجعه أو الشركة النشطة.');
      return;
    }
    final yes = await _confirmActivityDelete(
      title: 'تأكيد حذف صف نشاط',
      message: 'هل ترغب في حذف النشاط «$name» ( $code ) فقط؟ ستظل بقية الصفوف كما هي.',
    );
    if (!yes || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.deleteRecord(companyId: _companyId!, pageKey: _pageKey, recordKey: row['_مرجع داخلي'] ?? code);
      await Supabase.instance.client.from('activity_types').delete().eq('code', code);
      await _load();
      if (mounted) setState(() => _message = 'تم حذف النشاط «$name» فقط.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر حذف النشاط: $e');
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _delete() async {
    if (!_editing) { setState(() => _message = 'اضغط «تعديل» أولًا، وتأكد من صلاحية الحذف.'); return; }
    if (_rows.isEmpty || (_companyId ?? '').isEmpty) { setState(() => _message = 'لا توجد بيانات قابلة للحذف.'); return; }
    final count = _rows.length;
    final yes = await _confirmActivityDelete(
      title: 'تحذير: حذف الجريد بالكامل',
      message: 'هل ترغب في حذف جميع أنواع الأنشطة بالكامل؟ عدد الصفوف: $count. سيؤثر ذلك على قائمة الأنشطة المرتبطة بالتطبيق، ولا يمكن التراجع عن العملية.',
    );
    if (!yes || !mounted) return;
    setState(() => _saving = true);
    try {
      for (final row in List<Map<String,String>>.from(_rows)) {
        final code = (row['كود النشاط'] ?? '').trim();
        await _service.deleteRecord(companyId: _companyId!, pageKey: _pageKey, recordKey: row['_مرجع داخلي'] ?? code);
        if (code.isNotEmpty) await Supabase.instance.client.from('activity_types').delete().eq('code', code);
      }
      await _load();
      if (mounted) setState(() { _editing = false; _message = 'تم حذف جميع صفوف الجريد بنجاح.'; });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر إكمال حذف الجريد: $e');
    } finally { if (mounted) setState(() => _saving = false); }
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
      var nextNumber = int.tryParse(_nextActivityCode().substring(3)) ?? 1;
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
          'يظهر في التطبيق': (values['يظهر في التطبيق'] ?? 'true').toLowerCase() == 'false' ? 'false' : 'true',
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
          'name_en': row['اسم النشاط إنجليزي'] ?? '',
          'show_in_app': row['نشط'] == 'true' && row['يظهر في التطبيق'] == 'true',
        }, onConflict: 'code');
      }
      await _load();
      if (mounted) setState(() => _message = 'تم استيراد ${imported.length} نشاطًا بنجاح.');
    } catch (e) { if (mounted) setState(() => _message = 'تعذر استيراد Excel: $e'); }
  }

  Future<void> _exportExcel() async {
    if (_rows.isEmpty) { setState(() => _message = 'لا توجد بيانات لتصديرها.'); return; }
    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['أنواع الأنشطة'];
      const keys = ['ترتيب السطر', 'كود النشاط', 'اسم النشاط عربي', 'اسم النشاط إنجليزي', 'نشط', 'يظهر في التطبيق'];
      sheet.appendRow(keys.map((key) => excel.TextCellValue(key)).toList());
      for (final row in _rows) {
        sheet.appendRow(keys.map((key) => excel.TextCellValue(row[key] ?? '')).toList());
      }
      final bytes = workbook.encode();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel.');
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير أنواع الأنشطة',
        fileName: 'silsila_activity_types.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted) setState(() => _message = saved == null ? 'تم إلغاء تصدير Excel.' : 'تم تصدير بيانات الجريد بالكامل إلى Excel.');
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تصدير Excel: $e');
    }
  }

  Future<void> _printPdf() async {
    if (_rows.isEmpty) { setState(() => _message = 'لا توجد بيانات للطباعة.'); return; }
    try {
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      const keys = ['ترتيب السطر', 'كود النشاط', 'اسم النشاط عربي', 'اسم النشاط إنجليزي', 'نشط', 'يظهر في التطبيق'];
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(header: ErpPrintSupport.header, footer: ErpPrintSupport.footer, textDirection: pw.TextDirection.rtl, theme: pw.ThemeData.withFont(base: font, bold: font), build: (_) => [
        ErpPrintSupport.text('سلسلة — أنواع الأنشطة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(headers: keys, data: ErpPrintSupport.normalizeTable(_rows.map((row) => keys.map((key) => row[key] ?? '').toList()).toList())),
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
        _task('تحديث', Icons.refresh_rounded, const Color(0xFF2475B8), _loading || _saving ? null : _load),
        _task('إضافة', Icons.add_circle_outline_rounded, const Color(0xFF18865A), _saving ? null : _new),
        _task('حفظ', Icons.save_outlined, const Color(0xFF6F42C1), _saving || !_editing ? null : _save),
        _task('تعديل', Icons.edit_outlined, const Color(0xFFFFA015), _saving || _rows.isEmpty || _editing ? null : _editAll),
        _task('حذف', Icons.delete_outline_rounded, const Color(0xFFB42318), _saving || !_editing || _rows.isEmpty ? null : _delete),
        _task('معاينة', Icons.preview_outlined, const Color(0xFF6E2BA6), _preview),
        _task('طباعة', Icons.print_outlined, const Color(0xFFFF27C3), _printPdf),
        _task('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF16834A), _saving ? null : _importExcel),
        _task('تصدير Excel', Icons.file_download_outlined, const Color(0xFF16834A), _saving ? null : _exportExcel),
        _task('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFD32F2F), _printPdf),
      ]))),
      if (_message != null) Container(color: const Color(0xFFF7F2FC), padding: const EdgeInsets.all(7), child: Text(_message!, style: const TextStyle(fontSize: 11, color: Color(0xFF3E007D)))),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE4DDED)), borderRadius: BorderRadius.circular(8)), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowHeight: 40, dataRowMinHeight: 40, dataRowMaxHeight: 40, horizontalMargin: 5, columnSpacing: 5, headingRowColor: WidgetStateProperty.all(const Color(0xFFF1EAF9)), columns: const [DataColumn(label: Text('م')), DataColumn(label: Text('كود النشاط')), DataColumn(label: Text('اسم النشاط عربي')), DataColumn(label: Text('اسم النشاط إنجليزي')), DataColumn(label: Text('نشط')), DataColumn(label: Text('يظهر في التطبيق')), DataColumn(label: Text('إجراءات'))], rows: [
        for (var i = 0; i < _rows.length; i++) DataRow(cells: [
          DataCell(SizedBox(width: 38, child: Text('${i + 1}', textAlign: TextAlign.center))),
          DataCell(SizedBox(width: 82, child: Align(alignment: AlignmentDirectional.centerStart, child: Text(_rows[i]['كود النشاط'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6F42C1)))))),
          DataCell(SizedBox(width: 220, child: TextFormField(initialValue: _rows[i]['اسم النشاط عربي'] ?? '', key: ValueKey('activity-ar-$i-${_rows[i]['كود النشاط']}'), enabled: _editing, decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4)), onChanged: (v) => _rows[i]['اسم النشاط عربي'] = v))),
          DataCell(SizedBox(width: 220, child: TextFormField(initialValue: _rows[i]['اسم النشاط إنجليزي'] ?? '', key: ValueKey('activity-en-$i-${_rows[i]['كود النشاط']}'), enabled: _editing, decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 4)), onChanged: (v) => _rows[i]['اسم النشاط إنجليزي'] = v))),
          DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: (_rows[i]['نشط'] ?? 'true') == 'true', onChanged: _editing ? (v) => setState(() { final active = v ?? false; _rows[i]['نشط'] = active.toString(); if (!active) _rows[i]['يظهر في التطبيق'] = 'false'; }) : null)),
          DataCell(Checkbox(shape: const CircleBorder(), visualDensity: VisualDensity.compact, value: (_rows[i]['يظهر في التطبيق'] ?? 'true') == 'true' && (_rows[i]['نشط'] ?? 'true') == 'true', onChanged: _editing && (_rows[i]['نشط'] ?? 'true') == 'true' ? (v) => setState(() => _rows[i]['يظهر في التطبيق'] = (v ?? false).toString()) : null)),
          DataCell(IconButton(tooltip: 'حذف هذا النشاط فقط', onPressed: _saving || !_editing ? null : () => _deleteActivityRow(_rows[i]), icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)))),
        ]),
      ]))),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_rows.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(18), child: Text('لا توجد أنواع أنشطة محفوظة بعد. استخدم «إضافة» لإدخال أول نشاط.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
    ]));
  }
}
