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
  final _ar = TextEditingController();
  final _en = TextEditingController();
  final _address = TextEditingController();
  final _map = TextEditingController();
  final _m1 = TextEditingController();
  final _m2 = TextEditingController();
  final _w1 = TextEditingController();
  final _w2 = TextEditingController();
  final _company = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _deps = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _locs = [];
  List<Map<String, dynamic>> _geoRows = [];
  String _country = 'مصر', _gov = '', _district = '', _locality = '', _status = 'active';
  String? _admin, _dep, _job, _loc, _error, _message, _govGeoId, _districtGeoId;
  bool _loading = false, _saving = false;
  final _govs = const ['القاهرة','الجيزة','القليوبية','الإسكندرية','الشرقية','الدقهلية','الغربية','المنوفية','البحيرة','كفر الشيخ','دمياط','بورسعيد','الإسماعيلية','السويس','شمال سيناء','جنوب سيناء','بني سويف','الفيوم','المنيا','أسيوط','سوهاج','قنا','الأقصر','أسوان','البحر الأحمر','الوادي الجديد','مطروح'];
  final Map<String, List<String>> _districts = const {
    'القاهرة':['مدينة نصر','مصر الجديدة','المعادي','حلوان','التجمع الخامس','عين شمس','شبرا','المرج'],
    'الجيزة':['الدقي','العجوزة','الهرم','فيصل','أكتوبر','الشيخ زايد','البدرشين'],
    'القليوبية':['بنها','شبرا الخيمة','قليوب','الخصوص','الخانكة','طوخ','قها','كفر شكر'],
    'الإسكندرية':['المنتزه','شرق','وسط','غرب','العجمي'],
    'الشرقية':['الزقازيق','العاشر من رمضان','بلبيس','فاقوس'],
  };
  String get _cid => (widget.initialCompanyId ?? _company.text).trim();
  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String _s(dynamic v) => (v ?? '').toString();
  String? _first(Iterable<String> values) { for (final v in values) { return v; } return null; }
  List<Map<String, dynamic>> get _availableJobs => _jobs.where((j) => _dep == null || j['department_id'] == _dep).toList();

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    if (_cid.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }
  @override
  void dispose() {
    for (final c in [_code,_ar,_en,_address,_map,_m1,_m2,_w1,_w2,_company]) { c.dispose(); }
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
        _db!.from('erp_employees').select('id,employee_code,full_name,full_name_en,department_name,job_title,mobile_1,phone,is_active').eq('company_id', _cid).order('employee_code'),
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
      if (!mounted) return;
      setState(() {
        _employees = List<Map<String, dynamic>>.from(x[0]);
        _deps = List<Map<String, dynamic>>.from(x[1]);
        _jobs = List<Map<String, dynamic>>.from(x[2]);
        _locs = List<Map<String, dynamic>>.from(x[3]);
        _geoRows = geoRows;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل دليل الموظفين. طبّق ترحيل بيانات الموارد البشرية أولًا: ' + e.toString(); });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_cid.isEmpty || _db == null) { setState(() { _error = 'لا توجد شركة نشطة أو اتصال بقاعدة البيانات.'; }); return; }
    final depName = _first(_deps.where((x) => x['id'] == (_dep ?? _admin)).map((x) => _s(x['name_ar'])));
    final jobName = _first(_jobs.where((x) => x['id'] == _job).map((x) => _s(x['name_ar'])));
    final payload = <String, dynamic>{
      'company_id': _cid, 'employee_code': _code.text.trim().toUpperCase(),
      'full_name': _ar.text.trim(), 'full_name_en': _en.text.trim(), 'country': _country,
      'governorate': _gov, 'district': _district, 'locality': _locality,
      'address': _address.text.trim(), 'map_url': _map.text.trim(),
      'mobile_1': _m1.text.trim(), 'mobile_2': _m2.text.trim(),
      'work_mobile_1': _w1.text.trim(), 'work_mobile_2': _w2.text.trim(),
      'phone': _m1.text.trim(), 'department_id': _dep ?? _admin, 'job_id': _job,
      'work_location_id': _loc, 'department_name': depName, 'job_title': jobName,
      'employment_status': _status, 'is_active': _status == 'active',
    };
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _db!.from('erp_employees').insert(payload);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم حفظ بيانات الموظف بنجاح.'; });
      _clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'تعذر حفظ الموظف: ' + e.toString(); });
    }
  }

  void _clear() {
    for (final c in [_code,_ar,_en,_address,_map,_m1,_m2,_w1,_w2]) { c.clear(); }
    setState(() {
      _gov = ''; _district = ''; _locality = ''; _govGeoId = null; _districtGeoId = null; _admin = null; _dep = null;
      _job = null; _loc = null; _status = 'active';
    });
  }

  Widget _field(TextEditingController c, String label, {bool required = false, TextInputType? type}) {
    return SizedBox(width: 245, child: TextFormField(
      controller: c, keyboardType: type,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
      validator: (v) {
        final value = (v ?? '').trim();
        if (required && value.isEmpty) return 'حقل مطلوب';
        if (c == _code && value.isNotEmpty && !RegExp(r'^[A-Za-z]+-?[0-9]+$').hasMatch(value)) return 'استخدم حروفًا إنجليزية ثم أرقامًا مثل EMP-0001';
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
      Row(children: [
        const Expanded(child: Text('بيانات الموظفين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _purple))),
        IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh, color: _purple)),
        FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('حفظ')),
        const SizedBox(width: 8), OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.add), label: const Text('جديد')),
      ]),
      if (_cid.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة UUID', border: OutlineInputBorder()), onSubmitted: (_) => _load())),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_message != null) Text(_message!, style: const TextStyle(color: Colors.green)),
      Expanded(child: SingleChildScrollView(child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _section('بيانات أولية', Icons.badge_outlined, [
          _field(_code, 'كود الموظف (حروف إنجليزية ثم أرقام) *', required: true),
          _field(_ar, 'اسم الموظف عربي *', required: true), _field(_en, 'اسم الموظف إنجليزي'),
          _drop('الدولة', _country, ['مصر','السعودية','الإمارات','أخرى'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), (v) => setState(() { _country = v ?? 'مصر'; })),
          _drop('المحافظة', _geoRows.isEmpty ? (_gov.isEmpty ? null : _gov) : _govGeoId,
            (_geoRows.isEmpty ? _govs.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))) : _geoRows.where((g) => g['level'] == 'governorate').map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))).toList(),
            (v) => setState(() {
              _govGeoId = _geoRows.isEmpty ? null : v;
              _gov = _geoRows.isEmpty ? (v ?? '') : (_first(_geoRows.where((g) => _s(g['id']) == v).map((g) => _s(g['name_ar']))) ?? '');
              _district = ''; _locality = ''; _districtGeoId = null;
            })),
          _drop('مركز أو حي', _geoRows.isEmpty ? (_district.isEmpty ? null : _district) : _districtGeoId,
            (_geoRows.isEmpty ? (_districts[_gov] ?? ['المركز الرئيسي','وسط المدينة','حي أول','حي ثان']).map((v) => DropdownMenuItem<String>(value: v, child: Text(v))) : _geoRows.where((g) => g['level'] == 'district' && _s(g['parent_id']) == (_govGeoId ?? '')).map((g) => DropdownMenuItem<String>(value: _s(g['id']), child: Text(_s(g['name_ar']))))).toList(),
            (v) => setState(() {
              _districtGeoId = _geoRows.isEmpty ? null : v;
              _district = _geoRows.isEmpty ? (v ?? '') : _s(_geoRows.where((g) => _s(g['id']) == v).map((g) => g['name_ar']).firstOrNull);
              _locality = '';
            })),
          _drop('منطقة أو قرية', _locality.isEmpty ? null : _locality,
            (_geoRows.isEmpty ? ['المنطقة الرئيسية','المنطقة الصناعية','وسط البلد','منطقة سكنية','القرية الرئيسية'].map((v) => DropdownMenuItem<String>(value: v, child: Text(v))) : _geoRows.where((g) => g['level'] == 'area' && _s(g['parent_id']) == (_districtGeoId ?? '')).map((g) => DropdownMenuItem<String>(value: _s(g['name_ar']), child: Text(_s(g['name_ar']))))).toList(),
            (v) => setState(() { _locality = v ?? ''; })),
          _field(_address, 'العنوان التفصيلي'), _field(_map, 'رابط موقع Google Maps'),
          OutlinedButton.icon(onPressed: () async {
            final query = Uri.encodeComponent([_address.text, _district, _gov, _country].where((v) => v.trim().isNotEmpty).join(' '));
            final uri = Uri.tryParse(_map.text.trim().isEmpty ? 'https://www.google.com/maps/search/?api=1&query=' + query : _map.text.trim());
            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
          }, icon: const Icon(Icons.map_outlined), label: const Text('فتح الموقع على خرائط جوجل')),
        ]),
        _section('بيانات العمل والتنظيم', Icons.account_tree_outlined, [
          _drop('الإدارة', _admin, _deps.where((d) => d['department_level'] != 'section').map((d) => DropdownMenuItem(value: _s(d['id']), child: Text(_s(d['name_ar'])))).toList(), (v) => setState(() { _admin = v; _dep = null; _job = null; })),
          _drop('موقع العمل', _loc, _locs.map((d) => DropdownMenuItem(value: _s(d['id']), child: Text(_s(d['name_ar']) + ' • ' + _s(d['location_code'])))).toList(), (v) => setState(() { _loc = v; })),
          _drop('القسم', _dep, _deps.where((d) => d['department_level'] == 'section' && (_admin == null || d['parent_id'] == _admin)).map((d) => DropdownMenuItem(value: _s(d['id']), child: Text(_s(d['name_ar'])))).toList(), (v) => setState(() { _dep = v; _job = null; })),
          _drop('الوظيفة', _job, _availableJobs.map((j) => DropdownMenuItem(value: _s(j['id']), child: Text(_s(j['name_ar']) + ' • ' + _s(j['job_code'])))).toList(), (v) => setState(() { _job = v; })),
          _drop('حالة الموظف', _status, const [DropdownMenuItem(value: 'active', child: Text('نشط')), DropdownMenuItem(value: 'on_leave', child: Text('إجازة')), DropdownMenuItem(value: 'suspended', child: Text('موقوف')), DropdownMenuItem(value: 'terminated', child: Text('منتهي الخدمة'))], (v) => setState(() { _status = v ?? 'active'; })),
        ]),
        _section('بيانات الاتصال', Icons.phone_in_talk_outlined, [
          _field(_m1, 'موبايل 1', type: TextInputType.phone), _field(_m2, 'موبايل 2', type: TextInputType.phone),
          _field(_w1, 'موبايل عمل 1', type: TextInputType.phone), _field(_w2, 'موبايل عمل 2', type: TextInputType.phone),
        ]),
        const Text('دليل الموظفين المسجلين', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _purple)),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading) SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('م')), DataColumn(label: Text('الكود')), DataColumn(label: Text('اسم الموظف')), DataColumn(label: Text('الإدارة / القسم')), DataColumn(label: Text('الوظيفة')), DataColumn(label: Text('الموبايل')), DataColumn(label: Text('الحالة'))],
          rows: List.generate(_employees.length, (i) {
            final e = _employees[i];
            return DataRow(cells: [
              DataCell(Text((i + 1).toString())), DataCell(Text(_s(e['employee_code']))), DataCell(Text(_s(e['full_name']))),
              DataCell(Text(_s(e['department_name']))), DataCell(Text(_s(e['job_title']))),
              DataCell(Text(_s(_s(e['mobile_1']).isEmpty ? e['phone'] : e['mobile_1']))),
              DataCell(Text(e['is_active'] == true ? 'نشط' : 'غير نشط')),
            ]);
          }),
        )),
      ])))),
    ])),
  );
}
