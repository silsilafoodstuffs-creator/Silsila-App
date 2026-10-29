import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _purple = Color(0xFF3E007D);
const _orange = Color(0xFFFFA015);

class ErpEmployeeMasterScreen extends StatefulWidget {
  const ErpEmployeeMasterScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;
  @override
  State<ErpEmployeeMasterScreen> createState() => _ErpEmployeeMasterScreenState();
}

class _ErpEmployeeMasterScreenState extends State<ErpEmployeeMasterScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _ar = TextEditingController(text: 'إدارة عليا');
  final _en = TextEditingController();
  final _nationalId = TextEditingController();
  final _address = TextEditingController(text: 'أطلس 4 بجوار الملعب عملية 1248 بلوك 7 مدخل 1 شقة 11');
  final _map = TextEditingController();
  final _m1 = TextEditingController(text: '01121237271');
  final _m2 = TextEditingController();
  final _w1 = TextEditingController(text: '01044480160');
  final _w2 = TextEditingController();
  final _company = TextEditingController();
  final _hireDate = TextEditingController(text: '01-01-2027');
  final _contractFrom = TextEditingController(text: '01-01-2027');
  final _contractTo = TextEditingController(text: '31-12-2029');
  final _relativeMobile = TextEditingController(text: '01127283261');
  final _relativeRelation = TextEditingController(text: 'أخ');
  String _contractType = 'بعقد';
  String _workUnit = 'مكتب إداري';
  List<Map<String, dynamic>> _employeeDocs = [];
  static const _workUnits = ['مكتب إداري', 'مخازن', 'سيارات'];
  static const _supportingDocs = <(String, String)>[
    ('personal_id', 'صورة شخصية / بطاقة'), ('birth_certificate', 'شهادة الميلاد'),
    ('qualification', 'المؤهل الدراسي'), ('labor_card', 'كعب العمل'),
    ('insurance_print', 'برنت التأمينات'), ('military_status', 'شهادة / موقف التجنيد'),
    ('criminal_record', 'الفيش'), ('trust_receipt', 'إيصال أمانة'),
    ('health_certificate', 'الشهادة الصحية'), ('driving_license', 'رخصة القيادة'),
    ('bank_account', 'بيانات الحساب البنكي'),
  ];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _deps = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _locs = [];
  List<Map<String, dynamic>> _geoRows = [];
  String _country = 'مصر', _gov = 'القاهرة', _district = 'السلام', _locality = 'أطلس 4', _status = 'active';
  String? _admin, _dep, _job, _loc, _error, _message, _govGeoId, _districtGeoId;
  bool _loading = false, _saving = false;
  String? _selectedEmployeeId;
  bool _editing = false;
  final Map<String, TextEditingController> _employeeFilters = {for (final key in ['employee_code','full_name','department_name','job_title','mobile_1','is_active']) key: TextEditingController()};
  bool get _readOnly => _selectedEmployeeId != null && !_editing;
  List<Map<String, dynamic>> get _filteredEmployees => _employees.where((e) => _employeeFilters.entries.every((f) { final v = f.key == 'mobile_1' ? _s(_s(e['mobile_1']).isEmpty ? e['phone'] : e['mobile_1']) : f.key == 'is_active' ? (e['is_active'] == true ? 'نشط' : 'غير نشط') : _s(e[f.key]); return v.toLowerCase().contains(f.value.text.trim().toLowerCase()); })).toList();
  static const _contractTypes = ['بعقد','بدون عقد','شركة عمالة','مؤقت','يومية'];
  final _govs = const ['القاهرة','الجيزة','القليوبية','الإسكندرية','الشرقية','الدقهلية','الغربية','المنوفية','البحيرة','كفر الشيخ','دمياط','بورسعيد','الإسماعيلية','السويس','شمال سيناء','جنوب سيناء','بني سويف','الفيوم','المنيا','أسيوط','سوهاج','قنا','الأقصر','أسوان','البحر الأحمر','الوادي الجديد','مطروح'];
  final Map<String, List<String>> _districts = const {
    'القاهرة':['السلام','مدينة نصر','مصر الجديدة','المعادي','حلوان','التجمع الخامس','عين شمس','شبرا','المرج'], 
    'الجيزة':['الدقي','العجوزة','الهرم','فيصل','أكتوبر','الشيخ زايد','البدرشين'],
    'القليوبية':['بنها','شبرا الخيمة','قليوب','الخصوص','الخانكة','طوخ','قها','كفر شكر'],
    'الإسكندرية':['المنتزه','شرق','وسط','غرب','العجمي'],
    'الشرقية':['الزقازيق','العاشر من رمضان','بلبيس','فاقوس'],
  };
  String get _cid => (widget.initialCompanyId ?? _company.text).trim();
  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String _s(dynamic v) => (v ?? '').toString();
  String? _first(Iterable<String> values) { for (final v in values) { return v; } return null; }
  List<Map<String, dynamic>> get _availableJobs => _jobs.where((j) => _dep == null || j['department_id'] == _dep || j['department_id'] == _admin).toList();

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    if (_cid.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  @override
  void dispose() {
    for (final c in [_code,_ar,_en,_nationalId,_address,_map,_m1,_m2,_w1,_w2,_company,_hireDate,_contractFrom,_contractTo,_relativeMobile,_relativeRelation]) { c.dispose(); }
    for (final c in _employeeFilters.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    if (_cid.isEmpty || _db == null) {
      setState(() { _error = 'افتح بيانات الشركة أولًا لتحديد الشركة الحالية.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final x = await Future.wait([
        _db!.from('erp_employees').select('id,employee_code,full_name,full_name_en,department_name,job_title,mobile_1,phone,is_active,work_unit').eq('company_id', _cid).order('employee_code'),
        _db!.from('erp_hr_departments').select('id,department_code,name_ar,department_level,parent_id').eq('company_id', _cid).eq('is_active', true).order('department_code'),
        _db!.from('erp_hr_jobs').select('id,job_code,name_ar,department_id').eq('company_id', _cid).eq('is_active', true).order('job_code'),
        _db!.from('erp_hr_work_locations').select('id,location_code,name_ar').eq('company_id', _cid).eq('is_active', true).order('location_code'),
      ]);
      List<Map<String, dynamic>> geoRows = [];
      try {
        final geo = await _db!.from('erp_geographic_data')
            .select('id,parent_id,name_ar,level,is_active')
            .eq('company_id', _cid).eq('is_active', true).order('geo_code');
        geoRows = List<Map<String, dynamic>>.from(geo);
      } catch (_) {
        // Keep the built-in governorate list as a fallback if geography data has not been loaded.
      }
      if (geoRows.isNotEmpty) {
        if (!geoRows.any((g) => g['level'] == 'governorate' && g['name_ar'] == 'القاهرة')) {
          geoRows.add({'id': 'manual-cairo', 'parent_id': null, 'name_ar': 'القاهرة', 'level': 'governorate', 'is_active': true});
        }
        final cairo = geoRows.firstWhere((g) => g['level'] == 'governorate' && g['name_ar'] == 'القاهرة');
        if (!geoRows.any((g) => g['level'] == 'district' && g['name_ar'] == 'السلام' && _s(g['parent_id']) == _s(cairo['id']))) {
          geoRows.add({'id': 'manual-salam', 'parent_id': cairo['id'], 'name_ar': 'السلام', 'level': 'district', 'is_active': true});
        }
      }
      if (!mounted) return;
      setState(() {
        _employees = List<Map<String, dynamic>>.from(x[0]);
        _deps = List<Map<String, dynamic>>.from(x[1]);
        _jobs = List<Map<String, dynamic>>.from(x[2]);
        _locs = List<Map<String, dynamic>>.from(x[3]);
        _geoRows = geoRows;
        _loading = false;
      });
      if (geoRows.isNotEmpty) {
        final cairo = geoRows.firstWhere((g) => g['level'] == 'governorate' && g['name_ar'] == 'القاهرة');
        final salam = geoRows.firstWhere((g) => g['level'] == 'district' && g['name_ar'] == 'السلام' && _s(g['parent_id']) == _s(cairo['id']));
        setState(() { _govGeoId = _s(cairo['id']); _districtGeoId = _s(salam['id']); });
      }
      final top = _deps.where((d) => d['name_ar'] == 'الإدارة العليا').toList();
      final central = _deps.where((d) => d['name_ar'] == 'الإدارة المركزية').toList();
      final manager = _jobs.where((j) => j['name_ar'] == 'مدير عام').toList();
      if (top.isNotEmpty || central.isNotEmpty || manager.isNotEmpty) {
        setState(() {
          _admin = top.isEmpty ? null : _s(top.first['id']);
          _dep = central.isEmpty ? null : _s(central.first['id']);
          _job = manager.isEmpty ? null : _s(manager.first['id']);
        });
      }
      await _generateNextCode();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل دليل الموظفين. طبّق ترحيل بيانات الموارد البشرية أولًا: ' + e.toString(); });
    }
  }

  Future<void> _generateNextCode() async {
    if (_code.text.trim().isNotEmpty || _cid.isEmpty || _db == null) return;
    try {
      final rows = await _db!.from('erp_employees').select('employee_code').eq('company_id', _cid).limit(5000);
      var maxNumber = 0;
      for (final row in rows) {
        final match = RegExp(r'^[A-Za-z]+-?(\d+)$').firstMatch(_s(row['employee_code']));
        final number = match == null ? 0 : (int.tryParse(match.group(1) ?? '') ?? 0);
        if (number > maxNumber) maxNumber = number;
      }
      if (mounted && _code.text.trim().isEmpty) setState(() => _code.text = 'EMP-' + (maxNumber + 1).toString().padLeft(4, '0'));
    } catch (_) { if (mounted && _code.text.trim().isEmpty) setState(() => _code.text = 'EMP-0001'); }
  }
  DateTime? _parseDate(String value) {
    final match = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(value.trim());
    if (match == null) return null;
    return DateTime.tryParse('${match.group(3)}-${match.group(2)}-${match.group(1)}');
  }
  String _isoDate(String value) {
    final d = _parseDate(value); if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  String get _contractDuration {
    final start = _parseDate(_contractFrom.text); final end = _parseDate(_contractTo.text);
    if (_contractType != 'بعقد' || start == null || end == null || end.isBefore(start)) return '—';
    final inclusiveEnd = end.add(const Duration(days: 1));
    var months = (inclusiveEnd.year - start.year) * 12 + inclusiveEnd.month - start.month;
    if (inclusiveEnd.day < start.day) months--; if (months < 0) months = 0;
    final years = months ~/ 12; final remaining = months % 12;
    return years > 0 ? '${years} سنة${remaining > 0 ? ' و${remaining} شهر' : ''}' : '${months} شهر';
  }
  ({String label, Color color}) get _contractStatus {
    if (_contractType != 'بعقد') return (label: 'لا يوجد عقد محدد المدة', color: Colors.blueGrey);
    final end = _parseDate(_contractTo.text); if (end == null) return (label: 'تاريخ العقد غير مكتمل', color: Colors.blueGrey);
    final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day);
    if (end.isBefore(today)) return (label: 'منتهي', color: Colors.red);
    if (end.difference(today).inDays < 31) return (label: 'وشيك الانتهاء', color: _orange);
    return (label: 'ساري', color: Colors.green);
  }
  Widget _dateField(TextEditingController controller, String label, {double width = 245}) => SizedBox(width: width, child: TextFormField(
    controller: controller, keyboardType: TextInputType.datetime,
    decoration: InputDecoration(labelText: label, hintText: 'يوم-شهر-سنة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
    validator: (v) => (v ?? '').trim().isEmpty || _parseDate(v!) != null ? null : 'اكتب التاريخ بصيغة يوم-شهر-سنة',
    onChanged: (_) => setState(() {}),
  ));

  Future<void> _exportEmployeesExcel() async {
    if (_filteredEmployees.isEmpty) {
      setState(() => _message = 'لا توجد بيانات موظفين مطابقة للتصدير.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final workbook = Excel.createExcel();
      final sheet = workbook['الموظفون'];
      sheet.appendRow([
        TextCellValue('كود الموظف'),
        TextCellValue('اسم الموظف'),
        TextCellValue('الإدارة / القسم'),
        TextCellValue('الوظيفة'),
        TextCellValue('الموبايل'),
        TextCellValue('الحالة'),
      ]);
      for (final employee in _filteredEmployees) {
        sheet.appendRow([
          TextCellValue(_s(employee['employee_code'])),
          TextCellValue(_s(employee['full_name'])),
          TextCellValue(_s(employee['department_name'])),
          TextCellValue(_s(employee['job_title'])),
          TextCellValue(_s(_s(employee['mobile_1']).isEmpty ? employee['phone'] : employee['mobile_1'])),
          TextCellValue(employee['is_active'] == true ? 'نشط' : 'غير نشط'),
        ]);
      }
      final bytes = workbook.encode();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('تعذر إنشاء ملف Excel.');
      }
      await FileSaver.instance.saveFile(
        name: 'silsila_employees_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) setState(() => _message = 'تم تصدير ${_filteredEmployees.length} موظفًا إلى Excel.');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تصدير بيانات الموظفين إلى Excel: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _docsByType {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final doc in _employeeDocs) {
      (result[_s(doc['doc_type'])] ??= <Map<String, dynamic>>[]).add(doc);
    }
    return result;
  }

  Future<void> _loadEmployeeDocs(String employeeId) async {
    if (_db == null || _cid.isEmpty) return;
    try {
      final rows = await _db!.from('erp_employee_documents')
          .select('id,employee_id,doc_type,file_name,storage_path,mime_type,size_bytes,created_at')
          .eq('company_id', _cid).eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _employeeDocs = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تحميل مرفقات الموظف: $e');
    }
  }

  String _documentMime(String extension) => switch (extension.toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };

  Future<void> _pickEmployeeDocument(String type, String label) async {
    final employeeId = _selectedEmployeeId;
    if (_db == null || _cid.isEmpty || employeeId == null) {
      setState(() => _error = 'احفظ الموظف أولًا ثم اختره من الجدول لإضافة المسوغات.');
      return;
    }
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = 'تعذر قراءة الملف من الجهاز؛ جرّب اختيار الملف مرة أخرى.');
        return;
      }
      if (bytes.length > 8 * 1024 * 1024) {
        setState(() => _error = 'الحد الأقصى لحجم المرفق 8 ميجابايت.');
        return;
      }
      setState(() { _saving = true; _error = null; _message = null; });
      final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
      final mime = _documentMime(extension);
      final storagePath = '${_cid}/${employeeId}/employee_documents/${type}_${DateTime.now().microsecondsSinceEpoch}.${extension}';
      await _db!.storage.from('erp-company-assets').uploadBinary(
        storagePath, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      try {
        await _db!.from('erp_employee_documents').insert({
          'company_id': _cid, 'employee_id': employeeId, 'doc_type': type,
          'file_name': file.name, 'storage_path': storagePath,
          'mime_type': mime, 'size_bytes': bytes.length,
        });
      } catch (_) {
        await _db!.storage.from('erp-company-assets').remove([storagePath]);
        rethrow;
      }
      await _loadEmployeeDocs(employeeId);
      if (mounted) setState(() => _message = 'تم إرفاق "${label}" بنجاح.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر إرفاق "${label}": $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEmployeeDocument(Map<String, dynamic> doc) async {
    try {
      final url = await _db!.storage.from('erp-company-assets')
          .createSignedUrl(_s(doc['storage_path']), 300);
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw StateError('تعذر فتح الملف في تطبيق خارجي.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح المرفق: $e');
    }
  }

  Future<void> _deleteEmployeeDocument(Map<String, dynamic> doc) async {
    final id = _s(doc['id']);
    final path = _s(doc['storage_path']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: Text('هل تريد حذف "${_s(doc['file_name'])}" نهائيًا؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db!.from('erp_employee_documents').delete().eq('id', id).eq('company_id', _cid);
      await _db!.storage.from('erp-company-assets').remove([path]);
      if (mounted) setState(() {
        _employeeDocs.removeWhere((x) => _s(x['id']) == id);
        _message = 'تم حذف المرفق.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حذف المرفق: $e');
    }
  }

  Widget _employeeDocumentsSection() => _section('المسوغات والمرفقات من الجهاز', Icons.attach_file_outlined, [
    if (_selectedEmployeeId == null)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('احفظ الموظف أولًا ثم اختره من الجدول لإضافة المرفقات.'),
      ),
    for (final item in _supportingDocs)
      SizedBox(
        width: 265,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton.icon(
            onPressed: _selectedEmployeeId == null || _saving || _readOnly
                ? null : () => _pickEmployeeDocument(item.$1, item.$2),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(item.$2, overflow: TextOverflow.ellipsis),
          ),
          for (final doc in (_docsByType[item.$1] ?? const <Map<String, dynamic>>[]))
            ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined, color: _purple),
              title: Text(_s(doc['file_name']), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${((int.tryParse(_s(doc['size_bytes'])) ?? 0) / 1024).toStringAsFixed(0)} ك.ب'),
              trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'فتح المرفق', onPressed: () => _openEmployeeDocument(doc), icon: const Icon(Icons.open_in_new)),
                IconButton(tooltip: 'حذف المرفق', onPressed: _readOnly || _saving ? null : () => _deleteEmployeeDocument(doc), icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ]),
            ),
        ]),
      ),
  ]);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_cid.isEmpty || _db == null) { setState(() { _error = 'لا توجد شركة نشطة أو اتصال بقاعدة البيانات.'; }); return; }
    final depName = _first(_deps.where((x) => x['id'] == (_dep ?? _admin)).map((x) => _s(x['name_ar'])));
    final jobName = _first(_jobs.where((x) => x['id'] == _job).map((x) => _s(x['name_ar'])));
    final payload = <String, dynamic>{
      'company_id': _cid, 'employee_code': _code.text.trim().toUpperCase(),
      'full_name': _ar.text.trim(), 'full_name_en': _en.text.trim(), 'national_id': _nationalId.text.trim(), 'national_id_last4': _nationalId.text.trim().length == 14 ? _nationalId.text.trim().substring(10) : null, 'country': _country,
      'governorate': _gov, 'district': _district, 'locality': _locality,
      'address': _address.text.trim(), 'map_url': _map.text.trim(),
      'mobile_1': _m1.text.trim(), 'mobile_2': _m2.text.trim(),
      'work_mobile_1': _w1.text.trim(), 'work_mobile_2': _w2.text.trim(),
      'phone': _m1.text.trim(), 'administration_id': _admin, 'department_id': _dep ?? _admin, 'job_id': _job,
      'work_location_id': _loc, 'work_unit': _workUnit, 'department_name': depName, 'job_title': jobName,
      'employment_status': _status, 'is_active': _status == 'active',
      'hire_date': _isoDate(_hireDate.text).isEmpty ? null : _isoDate(_hireDate.text),
      'contract_type': _contractType,
      'contract_start_date': _contractType == 'بعقد' ? _isoDate(_contractFrom.text) : null,
      'contract_end_date': _contractType == 'بعقد' ? _isoDate(_contractTo.text) : null,
      'relative_mobile': _relativeMobile.text.trim(),
      'relative_relation': _relativeRelation.text.trim(),
    };
    if (_selectedEmployeeId != null && _nationalId.text.trim().isEmpty) { payload.remove('national_id'); payload.remove('national_id_last4'); }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      if (_selectedEmployeeId == null) { await _db!.from('erp_employees').insert(payload); } else { await _db!.from('erp_employees').update(payload).eq('id', _selectedEmployeeId!).eq('company_id', _cid); }
      if (!mounted) return;
      setState(() { _saving = false; _message = _selectedEmployeeId == null ? 'تم حفظ بيانات الموظف بنجاح.' : 'تم تعديل بيانات الموظف بنجاح.'; });
      _clear(generateCode: false);
      await _load();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ الموظف: ' + e.toString(); });
    }
  }

  void _clear({bool generateCode = true}) {
    _selectedEmployeeId = null;
    _editing = false;
    for (final c in [_code,_ar,_en,_nationalId,_address,_map,_m1,_m2,_w1,_w2,_relativeMobile,_relativeRelation]) { c.clear(); }
    _employeeDocs = [];
    _ar.text = 'إدارة عليا'; _address.text = 'أطلس 4 بجوار الملعب عملية 1248 بلوك 7 مدخل 1 شقة 11';
    _m1.text = '01121237271'; _w1.text = '01044480160'; _relativeMobile.text = '01127283261'; _relativeRelation.text = 'أخ';
    setState(() {
      _gov = 'القاهرة'; _district = 'السلام'; _locality = 'أطلس 4'; _govGeoId = null; _districtGeoId = null; _admin = null; _dep = null;
      _job = null; _loc = null; _status = 'active'; _contractType = 'بعقد'; _workUnit = 'مكتب إداري';
      _hireDate.text = '01-01-2027'; _contractFrom.text = '01-01-2027'; _contractTo.text = '31-12-2029';
    });
    if (generateCode) _generateNextCode();
  }


  Future<void> _selectEmployee(Map<String, dynamic> e) async {
    final id=_s(e['id']); if(id.isEmpty||_db==null)return;
    setState(()=>_loading=true);
    try {
      final rows=await _db!.from('erp_employees').select().eq('id',id).eq('company_id',_cid).limit(1);
      if(rows.isEmpty)throw StateError('لم يتم العثور على الموظف');
      final r=Map<String,dynamic>.from(rows.first); String v(String k)=>_s(r[k]);
      _code.text=v('employee_code'); _ar.text=v('full_name'); _en.text=v('full_name_en'); _nationalId.text=v('national_id');
      await _loadEmployeeDocs(id);
      _address.text=v('address'); _map.text=v('map_url'); _m1.text=v('mobile_1').isEmpty?v('phone'):v('mobile_1'); _m2.text=v('mobile_2');
      _w1.text=v('work_mobile_1'); _w2.text=v('work_mobile_2'); _relativeMobile.text=v('relative_mobile'); _relativeRelation.text=v('relative_relation');
      String dt(String s){final d=DateTime.tryParse(s);return d==null?s:d.day.toString().padLeft(2,'0')+'-'+d.month.toString().padLeft(2,'0')+'-'+d.year.toString();}
      _hireDate.text=dt(v('hire_date')); _contractFrom.text=dt(v('contract_start_date')); _contractTo.text=dt(v('contract_end_date'));
      if(!mounted)return;
      setState((){_selectedEmployeeId=id;_editing=false;_country=v('country').isEmpty?'مصر':v('country');_gov=v('governorate');_district=v('district');_locality=v('locality');
        _admin=_deps.any((d)=>_s(d['id'])==v('administration_id'))?v('administration_id'):null;
        _dep=_deps.any((d)=>_s(d['id'])==v('department_id'))?v('department_id'):null;
        _job=_jobs.any((j)=>_s(j['id'])==v('job_id'))?v('job_id'):null;
        _loc=_locs.any((l)=>_s(l['id'])==v('work_location_id'))?v('work_location_id'):null;
        _status=v('employment_status').isEmpty?(r['is_active']==true?'active':'inactive'):v('employment_status');
        _contractType=_contractTypes.contains(v('contract_type'))?v('contract_type'):'بدون عقد';_workUnit=_workUnits.contains(v('work_unit'))?v('work_unit'):'مكتب إداري';_loading=false;});
    }catch(e){if(mounted)setState(()=>_error='تعذر فتح بيانات الموظف: '+e.toString());}
  }

  Widget _employeeToolbar() {
    Widget a(String label,IconData icon,Color color,VoidCallback? fn)=>Padding(padding:const EdgeInsetsDirectional.only(end:5),child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:color,foregroundColor:Colors.white,visualDensity:VisualDensity.compact,padding:const EdgeInsets.symmetric(horizontal:10,vertical:10)),onPressed:fn,icon:Icon(icon,size:17),label:Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800))));
    return SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      a('تحديث',Icons.refresh_rounded,const Color(0xFF2475B8),_load),
      a('إضافة',Icons.add_rounded,const Color(0xFF18865A),(){_clear();setState(()=>_message='أدخل بيانات الموظف الجديد ثم اضغط حفظ.');}),
      a('حفظ',Icons.save_outlined,_purple,_saving?null:_save),
      a('تعديل',Icons.edit_outlined,_orange,_selectedEmployeeId==null?null:()=>setState(()=>_editing=true)),
      a('حذف',Icons.delete_outline_rounded,const Color(0xFFB42318),_selectedEmployeeId==null?null:_deleteEmployee),
      a('معاينة',Icons.preview_outlined,const Color(0xFF6E2BA6),_previewEmployee),
      a('طباعة',Icons.print_outlined,const Color(0xFFDB2777),_previewEmployee),
      a('Excel',Icons.file_download_outlined,const Color(0xFF16834A),_loading?null:_exportEmployeesExcel),
      a('PDF',Icons.picture_as_pdf_outlined,const Color(0xFFD32F2F),_previewEmployee),
      a('تهيئة 23 موظفًا',Icons.group_add_outlined,const Color(0xFF0F766E),_saving?null:_seedRequestedStaff),
    ]));
  }

  Widget _employeeGrid() {
    const cols=< (String,String) >[('employee_code','الكود'),('full_name','اسم الموظف'),('department_name','الإدارة / القسم'),('job_title','الوظيفة'),('mobile_1','الموبايل'),('is_active','الحالة')];
    final data=_filteredEmployees;
    return Container(height:230,margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:const Color(0xFFE9E1F1)),borderRadius:BorderRadius.circular(12)),child:Column(children:[
      Row(children:[const Expanded(child:Text('دليل الموظفين المسجلين — اختر موظفًا لعرض بياناته بالأعلى',style:TextStyle(fontWeight:FontWeight.w900,color:_purple))),Text(data.length.toString()+' / '+_employees.length.toString())]),
      Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SingleChildScrollView(child:DataTable(headingRowHeight:72,dataRowMinHeight:38,dataRowMaxHeight:44,
        columns:cols.map((col)=>DataColumn(label:SizedBox(width:col.$1=='full_name'?175:145,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(col.$2,style:const TextStyle(fontWeight:FontWeight.w900)),
          SizedBox(height:30,child:TextField(controller:_employeeFilters[col.$1],onChanged:(_)=>setState((){}),decoration:const InputDecoration(hintText:'بحث...',isDense:true,border:OutlineInputBorder(),prefixIcon:Icon(Icons.search,size:14),contentPadding:EdgeInsets.symmetric(horizontal:5,vertical:5))))
        ])))).toList(),
        rows:data.map((e)=>DataRow(selected:_s(e['id'])==_selectedEmployeeId,onSelectChanged:(_)=>_selectEmployee(e),cells:[
          DataCell(Text(_s(e['employee_code']))),DataCell(Text(_s(e['full_name']))),DataCell(Text(_s(e['department_name']))),DataCell(Text(_s(e['job_title']))),DataCell(Text(_s(_s(e['mobile_1']).isEmpty?e['phone']:e['mobile_1']))),DataCell(Text(e['is_active']==true?'نشط':'غير نشط'))
        ])).toList()))))
    ]));
  }

  Future<void> _seedRequestedStaff() async {
    if (_db == null || _cid.isEmpty || _saving || _loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تهيئة بيانات الموظفين'),
        content: const Text('سيتم إنشاء الموظفين الـ23 المطلوبين وربط مستخدمي الإدارة المركزية وأمناء الخزائن. الموبايلات والأرقام القومية بيانات وهمية مؤقتة. لن تتكرر السجلات الموجودة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء البيانات')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final db = _db!;
      final departments = _deps.map((r) => Map<String,dynamic>.from(r)).toList();
      final jobs = _jobs.map((r) => Map<String,dynamic>.from(r)).toList();
      final locations = _locs.map((r) => Map<String,dynamic>.from(r)).toList();
      final branches = (await db.from('erp_branches').select('id,branch_code').eq('company_id', _cid).eq('is_active', true)).map((r) => Map<String,dynamic>.from(r)).toList();
      final types = (await db.from('erp_user_types').select('id,name_ar').eq('company_id', _cid)).map((r) => Map<String,dynamic>.from(r)).toList();
      var typeRows = types.where((r) => _s(r['name_ar']) == 'موظف').toList();
      if (typeRows.isEmpty) {
        final createdType = await db.from('erp_user_types').insert({
          'company_id': _cid, 'name_ar': 'موظف', 'name_en': 'Employee',
          'description': 'مستخدم داخلي للموظفين', 'is_active': true, 'show_at_login': false,
        }).select('id,name_ar').single();
        typeRows = [Map<String, dynamic>.from(createdType)];
      }
      final employeeType = typeRows.first;
      final cashboxes = (await db.from('erp_cashboxes').select('id,cashbox_code,branch_id,is_bank_account').eq('company_id', _cid).eq('is_active', true).order('cashbox_code')).map((r) => Map<String,dynamic>.from(r)).toList();
      final data = <Map<String,dynamic>>[
        {'name':'علياء مجدي','en':'Alia Magdy','job':'مسئول مشتريات','dep':'مشتريات شركات','dc':'PUR-SEC-05','jc':'JOB-041','loc':'LOC-001','area':'أطلس 4','central':true},
        {'name':'أمنية جمال','en':'Omnia Gamal','job':'مسئول مشتريات','dep':'مشتريات تجار','dc':'PUR-SEC-06','jc':'JOB-041','loc':'LOC-001','area':'جمال عبد الناصر','central':true},
        {'name':'زهراء عبد العاطي','en':'Zahraa Abdelatty','job':'مندوب مبيعات Indoor','dep':'مبيعات داخلية','dc':'SAL-SEC-06','jc':'JOB-043','loc':'LOC-001','area':'اسبيكو','central':true},
        {'name':'علي الجمل','en':'Ali El Gamal','job':'مندوب مبيعات Outdoor','dep':'مبيعات خارجية','dc':'SAL-SEC-07','jc':'JOB-044','loc':'LOC-001','area':'النهضة','central':true},
        {'name':'هدي محمد','en':'Hoda Mohamed','job':'مندوب مبيعات Joker','dep':'مبيعات جوكر','dc':'SAL-SEC-08','jc':'JOB-045','loc':'LOC-001','area':'الحرفيين','central':true},
        {'name':'عبير عبد العاطي','en':'Abeer Abdelatty','job':'مندوب مبيعات Call Center','dep':'مبيعات كول سنتر','dc':'SAL-SEC-11','jc':'JOB-046','loc':'LOC-001','area':'مساكن المحمودية','central':true},
        {'name':'دنيا علي','en':'Donia Ali','job':'مندوب مبيعات Indoor','dep':'مبيعات داخلية','dc':'SAL-SEC-06','jc':'JOB-043','loc':'LOC-001','area':'مدينة السلام 1','central':true},
        {'name':'محمد عياد','en':'Mohamed Ayad','job':'مشرف حركة سيارات','dep':'حركة سيارات','dc':'MOV-SEC-03','jc':'JOB-049','loc':'001','branch':'001','area':'مدينة السلام 2'},
        {'name':'محمود ابراهيم','en':'Mahmoud Ibrahim','job':'مشرف حركة سيارات','dep':'حركة سيارات','dc':'MOV-SEC-03','jc':'JOB-049','loc':'002','branch':'002','area':'مساكن الدلتا'},
        {'name':'اسراء علي','en':'Esraa Ali','job':'مندوب تطبيقات','dep':'تطبيقات','dc':'SAL-SEC-09','jc':'JOB-047','loc':'LOC-001','area':'أبو رجيلة','central':true},
        {'name':'أحمد عطية','en':'Ahmed Attia','job':'مندوب متابعة عملاء','dep':'متابعة العملاء','dc':'SAL-SEC-10','jc':'JOB-048','loc':'LOC-001','area':'بركة النصر','central':true},
        {'name':'نادر ابراهيم','en':'Nader Ibrahim','job':'محاسب مراقبة مخزون','dep':'مراقبة المخزون','dc':'FIN-SEC-07','jc':'JOB-050','loc':'001','branch':'001','area':'الشواك'},
        {'name':'شعبان عيسي','en':'Shaaban Eissa','job':'محاسب مراقبة مخزون','dep':'مراقبة المخزون','dc':'FIN-SEC-07','jc':'JOB-050','loc':'002','branch':'002','area':'منشية السادات'},
        {'name':'محمود سمير','en':'Mahmoud Samir','job':'محاسب عملاء','dep':'حسابات العملاء','dc':'FIN-SEC-05','jc':'JOB-051','loc':'LOC-001','area':'السلام أول','central':true},
        {'name':'خالد السيد','en':'Khaled El Sayed','job':'مراجع بنوك','dep':'الخزينة والبنوك','dc':'FIN-SEC-02','jc':'JOB-052','loc':'LOC-001','area':'السلام ثان','central':true},
        {'name':'شمس نافع','en':'Shams Nafea','job':'مراجع خزائن','dep':'الخزينة والبنوك','dc':'FIN-SEC-02','jc':'JOB-053','loc':'LOC-001','area':'مساكن أطلس','central':true},
        {'name':'محمود فهمي','en':'Mahmoud Fahmy','job':'محاسب حوافز موردين','dep':'حسابات الموردين','dc':'FIN-SEC-06','jc':'JOB-054','loc':'LOC-001','area':'مساكن النهضة','central':true},
        {'name':'محمد حمدي','en':'Mohamed Hamdy','job':'محاسب مصروفات','dep':'حسابات منتظمة','dc':'FIN-SEC-08','jc':'JOB-055','loc':'LOC-001','area':'عرب الطويل','central':true},
        {'name':'احمد شحتة','en':'Ahmed Shehta','job':'أمين خزينة','dep':'الخزينة والبنوك','dc':'FIN-SEC-02','jc':'JOB-004','loc':'LOC-001','area':'النهضة الجديدة','central':true,'cashbox':'CSH-0001'},
        {'name':'يحي محمد','en':'Yehia Mohamed','job':'مشرف حركة مخازن','dep':'حركة مخازن','dc':'MOV-SEC-04','jc':'JOB-056','loc':'001','branch':'001','area':'مساكن الحرفيين'},
        {'name':'محمد فوزي','en':'Mohamed Fawzy','job':'مشرف حركة مخازن','dep':'حركة مخازن','dc':'MOV-SEC-04','jc':'JOB-056','loc':'002','branch':'002','area':'مساكن اسبيكو'},
        {'name':'محمد يوسف','en':'Mohamed Youssef','job':'أمين خزينة','dep':'الخزينة والبنوك','dc':'FIN-SEC-02','jc':'JOB-004','loc':'001','branch':'001','area':'مساكن السلام','cashbox':'CSH-0002'},
        {'name':'محمد بكر','en':'Mohamed Bakr','job':'أمين خزينة','dep':'الخزينة والبنوك','dc':'FIN-SEC-02','jc':'JOB-004','loc':'002','branch':'002','area':'منطقة النهضة الشرقية','cashbox':'CSH-0005'},
      ];
      final existing = (await db.from('erp_employees').select('id,employee_code,full_name').eq('company_id', _cid)).map((r) => Map<String,dynamic>.from(r)).toList();
      var maxEmployee = 0;
      for (final row in existing) {
        final parts = _s(row['employee_code']).split('-');
        final n = int.tryParse(parts.last) ?? 0;
        if (n > maxEmployee) maxEmployee = n;
      }
      var createdEmployees = 0;
      final idsByName = <String,String>{for (final row in existing) _s(row['full_name']):_s(row['id'])};
      for (final item in data) {
        if (idsByName.containsKey(_s(item['name']))) continue;
        final depRows = departments.where((r) => _s(r['department_code']) == _s(item['dc'])).toList();
        final jobRows = jobs.where((r) => _s(r['job_code']) == _s(item['jc'])).toList();
        final locRows = locations.where((r) => _s(r['location_code']) == _s(item['loc'])).toList();
        final branchRows = branches.where((r) => _s(r['branch_code']) == _s(item['branch'])).toList();
        if (depRows.isEmpty || jobRows.isEmpty || locRows.isEmpty) throw StateError('بيانات الإدارة أو القسم أو الوظيفة أو الموقع غير مكتملة للموظف ' + _s(item['name']));
        final dep = depRows.first;
        final n = ++maxEmployee;
        final nationalId = n.toString().padLeft(14,'0');
        final inserted = await db.from('erp_employees').insert({
          'company_id':_cid,'branch_id':branchRows.isEmpty ? null : branchRows.first['id'],
          'employee_code':'EMP-' + n.toString().padLeft(4,'0'),'full_name':item['name'],'full_name_en':item['en'],
          'national_id':nationalId,'national_id_last4':nationalId.substring(10),
          'phone':'010000000' + n.toString().padLeft(2,'0'),'mobile_1':'010000000' + n.toString().padLeft(2,'0'),
          'work_mobile_1':'011000000' + n.toString().padLeft(2,'0'),'job_title':item['job'],'department_name':item['dep'],
          'administration_id':dep['parent_id'],'department_id':dep['id'],'job_id':jobRows.first['id'],'work_location_id':locRows.first['id'],
          'employment_status':'active','is_active':true,'country':'مصر','governorate':'القاهرة','district':'السلام',
          'locality':item['area'],'address':'أطلس 4 بجوار الملعب عملية 1248 بلوك 7 مدخل 1 شقة 11',
          'hire_date':'2027-01-01','contract_type':'بعقد','contract_start_date':'2027-01-01','contract_end_date':'2029-12-31',
          'relative_mobile':'011100000' + n.toString().padLeft(2,'0'),'relative_relation':'أخ',
          'notes':'بيانات أولية مؤقتة؛ رقم قومي وموبايل وهميان للتعديل لاحقًا',
        }).select('id').single();
        idsByName[_s(item['name'])]=_s(inserted['id']);
        createdEmployees++;
      }
      final users = (await db.from('erp_users').select('id,user_code,employee_id,cashbox_id').eq('company_id',_cid)).map((r)=>Map<String,dynamic>.from(r)).toList();
      var maxUser = 0;
      for (final row in users) {
        final digits = _s(row['user_code']).replaceAll(RegExp('[^0-9]'), '');
        final n = int.tryParse(digits) ?? 0;
        if (n > maxUser) maxUser = n;
      }
      var createdUsers = 0;
      var permissionWarnings = 0;
      for (final item in data.where((r)=>r['central']==true || r['cashbox']!=null)) {
        final employeeId = idsByName[_s(item['name'])];
        if (employeeId == null) continue;
        final existingUserRows = users.where((u)=>_s(u['employee_id'])==employeeId).toList();
        final isCashier = _s(item['job']) == 'أمين خزينة';
        final targetBranchRows = branches.where((b) => _s(b['branch_code']) == _s(item['branch'])).toList();
        final targetBranchId = targetBranchRows.isEmpty ? null : _s(targetBranchRows.first['id']);
        final cb = isCashier ? cashboxes.where((r) =>
            r['is_bank_account'] != true &&
            (targetBranchId == null ? _s(r['branch_id']).isEmpty : _s(r['branch_id']) == targetBranchId)
          ).toList() : <Map<String, dynamic>>[];
        if (isCashier && cb.isEmpty) {
          throw StateError('لا توجد خزينة نشطة مرتبطة بموقع أمين الخزينة ' + _s(item['name']) + '. افتح شاشة الخزائن واضغط «تهيئة الخزائن» أولًا.');
        }
        late Map<String,dynamic> user;
        if (existingUserRows.isEmpty) {
          maxUser++;
          user = Map<String,dynamic>.from(await db.from('erp_users').insert({
            'company_id':_cid,'user_code':'USR' + maxUser.toString().padLeft(4,'0'),
            'name_ar':item['name'],'name_en':item['en'],'user_type_id':employeeType['id'],
            'employee_id':employeeId,'is_active':true,'has_sub_warehouse':false,
            'cashbox_id':isCashier ? cb.first['id'] : null,
          }).select('id,user_code,employee_id,cashbox_id').single());
          users.add(user);
          createdUsers++;
        } else {
          user = existingUserRows.first;
          if (isCashier && cb.isNotEmpty && _s(user['cashbox_id']) != _s(cb.first['id'])) {
            await db.from('erp_users').update({'cashbox_id':cb.first['id']}).eq('id',user['id']).eq('company_id',_cid);
          }
        }
        final title = _s(item['job']);
        final menuKey = title.contains('مشتريات') ? 'مشتريات' : (title.contains('مندوب') ? 'مبيعات' : (title.contains('محاسب') || title.contains('مراجع') || title.contains('خزينة') ? 'حسابات مالية' : 'مخازن'));
        try {
          await db.from('erp_user_permission_matrix').upsert({
            'company_id':_cid,'user_id':user['id'],'menu_name':menuKey,
            'submenu_name':'الكل','page_name':'الكل',
            'can_refresh':true,'can_add':true,'can_save':true,'can_edit':true,
            'can_delete':false,'can_preview':true,'can_print':true,
            'can_import_excel':true,'can_print_pdf':true,'can_access':true,
            'show_in_quick_tasks':false,
          },onConflict:'user_id,menu_name,submenu_name,page_name');
        } catch (_) { permissionWarnings++; }
      }
      if (!mounted) return;
      setState(() {
        _saving=false;
        _message='تمت التهيئة: أضيف ' + createdEmployees.toString() + ' موظفًا و' + createdUsers.toString() + ' مستخدم ERP.' + (permissionWarnings > 0 ? ' تعذر حفظ صلاحيات ' + permissionWarnings.toString() + ' مستخدم.' : ' تم حفظ الصلاحيات المؤقتة.');
      });
      await _load();
    } catch (e) {
      if (mounted) setState(() { _saving=false; _error='تعذرت تهيئة الموظفين والمستخدمين: ' + e.toString(); });
    }
  }

  Future<void> _deleteEmployee() async {
    final id = _selectedEmployeeId;
    if (id == null || _db == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد حذف الموظف'),
        content: Text('هل تريد حذف ' + _ar.text + '؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _db!.from('erp_employees').delete().eq('id', id).eq('company_id', _cid);
      _clear();
      await _load();
      if (mounted) setState(() => _message = 'تم حذف الموظف.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر حذف الموظف: ' + e.toString());
    }
  }

  Future<void> _previewEmployee() async {
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('معاينة بيانات الموظف'),content:Text('الكود: '+_code.text+'\nالاسم: '+_ar.text+'\nالإدارة: '+(_dep??_admin??'—')+'\nالوظيفة: '+(_job??'—')+'\nالموبايل: '+_m1.text),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));
  }

  Widget _field(TextEditingController c, String label, {bool required = false, TextInputType? type, double width = 245}) {
    return SizedBox(width: width, child: TextFormField(
      controller: c, keyboardType: type,
      readOnly: c == _code,
      enableInteractiveSelection: c != _code,
      decoration: InputDecoration(labelText: label, prefixIcon: c == _code ? const Icon(Icons.lock_outline, size: 18) : null, filled: c == _code, fillColor: c == _code ? const Color(0xFFF1EEF4) : null, helperText: c == _code ? 'يُنشأ تلقائيًا ولا يمكن تعديله' : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
      validator: (v) {
        final value = (v ?? '').trim();
        if (required && value.isEmpty) return 'حقل مطلوب';
        if (c == _code && value.isNotEmpty && !RegExp(r'^[A-Za-z]+-?[0-9]+$').hasMatch(value)) return 'استخدم حروفًا إنجليزية ثم أرقامًا مثل EMP-0001';
        if (c == _nationalId && value.isNotEmpty && !RegExp(r'^\d{14}$').hasMatch(value)) return 'الرقم القومي يجب أن يتكون من 14 رقمًا';
        return null;
      },
    ));
  }

  Widget _drop(String label, String? value, List<DropdownMenuItem<String>> items, ValueChanged<String?> change, {double width = 245}) {
    return SizedBox(width: width, child: DropdownButtonFormField<String>(
      value: value, items: items, isExpanded: true, onChanged: change,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
    ));
  }

  List<DropdownMenuItem<String>> _areaItems() {
    if (_geoRows.isEmpty) {
      final options = <String>{_locality, 'المنطقة الرئيسية', 'المنطقة الصناعية', 'وسط البلد', 'منطقة سكنية', 'القرية الرئيسية'}
          .where((value) => value.isNotEmpty);
      return options.map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList();
    }
    final items = _geoRows
        .where((row) => row['level'] == 'area' && _s(row['parent_id']) == (_districtGeoId ?? '') && _s(row['name_ar']) != _locality)
        .map((row) => DropdownMenuItem<String>(value: _s(row['name_ar']), child: Text(_s(row['name_ar']))))
        .toList();
    if (_locality.isNotEmpty) items.add(DropdownMenuItem<String>(value: _locality, child: Text(_locality)));
    return items;
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE9E1F1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(icon, color: _orange), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _purple))]),
        const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 12, children: children),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('بيانات الموظفين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _purple)),
      const SizedBox(height: 8),
      _employeeToolbar(),
      if (_cid.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة UUID', border: OutlineInputBorder()), onSubmitted: (_) => _load())),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_message != null) Text(_message!, style: const TextStyle(color: Colors.green)),
      if (_readOnly) const Text('تم تحميل الموظف المحدد؛ اضغط تعديل قبل تغيير بياناته.', style: TextStyle(color: _purple,fontWeight:FontWeight.w700)),
      Expanded(child: SingleChildScrollView(child: IgnorePointer(ignoring: _readOnly, child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section('بيانات أولية', Icons.badge_outlined, [
          _field(_code, 'كود الموظف التلقائي *', required: true, width: 185),
          _field(_ar, 'اسم الموظف عربي *', required: true, width: 220), _field(_en, 'اسم الموظف إنجليزي', width: 220),
          _drop('الدولة', _country, ['مصر','السعودية','الإمارات','أخرى'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), (v) => setState(() { _country = v ?? 'مصر'; }), width: 125),
          _drop('المحافظة', _geoRows.isEmpty ? (_gov.isEmpty ? null : _gov) : _govGeoId,
            (_geoRows.isEmpty ? _govs.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))) : _geoRows.where((g) => g['level'] == 'governorate').map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))).toList(),
            (v) => setState(() {
              _govGeoId = _geoRows.isEmpty ? null : v;
              _gov = _geoRows.isEmpty ? (v ?? '') : (_first(_geoRows.where((g) => _s(g['id']) == v).map((g) => _s(g['name_ar']))) ?? '');
              _district = ''; _locality = ''; _districtGeoId = null;
            }), width: 145),
          _drop('مركز / حي', _geoRows.isEmpty ? (_district.isEmpty ? null : _district) : _districtGeoId,
            (_geoRows.isEmpty ? (_districts[_gov] ?? ['المركز الرئيسي','وسط المدينة','حي أول','حي ثان']).map((v) => DropdownMenuItem<String>(value: v, child: Text(v))) : _geoRows.where((g) => g['level'] == 'district' && _s(g['parent_id']) == (_govGeoId ?? '')).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))).toList(),
            (v) => setState(() {
              _districtGeoId = _geoRows.isEmpty ? null : v;
              _district = _geoRows.isEmpty ? (v ?? '') : (_first(_geoRows.where((g) => _s(g['id']) == v).map((g) => _s(g['name_ar']))) ?? '');
              _locality = '';
            }), width: 150),
          _drop('منطقة / قرية', _locality.isEmpty ? null : _locality,
            _areaItems(),
            (v) => setState(() { _locality = v ?? ''; }), width: 155),
          _field(_address, 'العنوان التفصيلي', width: 285), _field(_map, 'رابط موقع Google Maps', width: 285),
          OutlinedButton.icon(onPressed: () async {
            final query = Uri.encodeComponent([_address.text, _district, _gov, _country].where((v) => v.trim().isNotEmpty).join(' '));
            final uri = Uri.tryParse(_map.text.trim().isEmpty ? 'https://www.google.com/maps/search/?api=1&query=' + query : _map.text.trim());
            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          }, icon: const Icon(Icons.map_outlined), label: const Text('فتح الموقع على الخرائط')),
          _field(_nationalId, 'الرقم القومي (14 رقمًا) *', required: true, type: TextInputType.number, width: 190),
        ]),
        _section('بيانات العمل والتنظيم', Icons.account_tree_outlined, [
          _drop('الإدارة', _admin, _deps.where((d) => d['department_level'] != 'section').map((d) => DropdownMenuItem(value: _s(d['id']), child: Text(_s(d['name_ar'])))).toList(), (v) => setState(() { _admin = v; _dep = null; _job = null; }), width: 175),
          _drop('القسم', _dep, _deps.where((d) => (d['department_level'] == 'section' || d['department_level'] == 'department') && (_admin == null || d['parent_id'] == _admin)).map((d) => DropdownMenuItem(value: _s(d['id']), child: Text(_s(d['name_ar'])))).toList(), (v) => setState(() { _dep = v; _job = null; }), width: 175),
          _drop('موقع العمل', _loc, _locs.map((d) => DropdownMenuItem(value: _s(d['id']), child: Text(_s(d['name_ar']) + ' • ' + _s(d['location_code'])))).toList(), (v) => setState(() { _loc = v; }), width: 175),
          _drop('وحدة العمل', _workUnit, _workUnits.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(), (v) => setState(() => _workUnit = v ?? 'مكتب إداري'), width: 155),
          _drop('الوظيفة', _job, _availableJobs.map((j) => DropdownMenuItem(value: _s(j['id']), child: Text(_s(j['name_ar']) + ' • ' + _s(j['job_code'])))).toList(), (v) => setState(() { _job = v; }), width: 175),
          _dateField(_hireDate, 'تاريخ التعيين', width: 150),
          SizedBox(width: 400, child: Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final item in const [('active', 'نشط'), ('inactive', 'غير نشط'), ('suspended', 'موقوف مؤقتًا'), ('terminated', 'منتهي الخدمة')])
              InkWell(
                onTap: () => setState(() => _status = item.$1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(value: _status == item.$1, onChanged: (checked) { if (checked == true) setState(() => _status = item.$1); }, visualDensity: VisualDensity.compact, activeColor: _purple),
                  Text(item.$2, style: const TextStyle(fontSize: 13)),
                ]),
              ),
          ])),
          _drop('نوع العقد', _contractType, _contractTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), (v) => setState(() => _contractType = v ?? 'بدون عقد'), width: 145),
          if (_contractType == 'بعقد') ...[
            _dateField(_contractFrom, 'تاريخ العقد من', width: 145), _dateField(_contractTo, 'تاريخ العقد إلى', width: 145),
            SizedBox(width: 115, child: Padding(padding: const EdgeInsets.only(top: 14), child: Text('المدة: $_contractDuration', style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)))),
            SizedBox(width: 120, child: Padding(padding: const EdgeInsets.only(top: 14), child: Text(_contractStatus.label, style: TextStyle(color: _contractStatus.color, fontWeight: FontWeight.w900)))),
          ],
        ]),
        _section('بيانات الاتصال', Icons.phone_in_talk_outlined, [
          _field(_m1, 'موبايل 1', type: TextInputType.phone, width: 155), _field(_m2, 'موبايل 2', type: TextInputType.phone, width: 155),
          _field(_w1, 'موبايل عمل 1', type: TextInputType.phone, width: 155), _field(_w2, 'موبايل عمل 2', type: TextInputType.phone, width: 155),
          _field(_relativeMobile, 'موبايل أحد الأقارب', type: TextInputType.phone, width: 180), _field(_relativeRelation, 'صلة القرابة', width: 130),
        ]),
        _employeeDocumentsSection(),
      ]))))),
      _employeeGrid(),
    ])),
  );
}
