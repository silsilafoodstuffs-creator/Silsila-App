import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hrStructurePurple = Color(0xFF3E007D);
const _hrStructureOrange = Color(0xFFFFA015);

class ErpHrStructureScreen extends StatefulWidget {
  const ErpHrStructureScreen({super.key, this.initialCompanyId, this.initialTab});
  final String? initialCompanyId;
  final String? initialTab;
  @override
  State<ErpHrStructureScreen> createState() => _ErpHrStructureScreenState();
}

class _ErpHrStructureScreenState extends State<ErpHrStructureScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _code = TextEditingController();
  final _ar = TextEditingController();
  final _en = TextEditingController();
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _locations = [];
  String? _error;
  bool _loading = false;

  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String get _companyId => (widget.initialCompanyId ?? '').trim();

  @override
  void initState() {
    super.initState();
    final index = widget.initialTab == 'مواقع العمل' ? 3 : widget.initialTab == 'درجات الوظائف' ? 2 : widget.initialTab == 'الوظائف والدرجات' ? 1 : 0;
    _tabs = TabController(length: 4, vsync: this, initialIndex: index);
    _load();
  }
  @override
  void dispose() {
    _tabs.dispose(); _code.dispose(); _ar.dispose(); _en.dispose(); super.dispose();
  }

  Future<void> _load() async {
    if (_companyId.isEmpty || _db == null) {
      setState(() { _error = 'لا توجد شركة محددة. افتح بيانات الشركة أولًا.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await Future.wait([
        _db!.from('erp_hr_departments').select().eq('company_id', _companyId).order('department_code'),
        _db!.from('erp_hr_jobs').select().eq('company_id', _companyId).order('job_code'),
        _db!.from('erp_hr_job_grades').select().eq('company_id', _companyId).order('rank_order'),
        _db!.from('erp_hr_work_locations').select().eq('company_id', _companyId).order('location_code'),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = List<Map<String, dynamic>>.from(result[0]);
        _jobs = List<Map<String, dynamic>>.from(result[1]);
        _grades = List<Map<String, dynamic>>.from(result[2]);
        _locations = List<Map<String, dynamic>>.from(result[3]);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل بيانات الهيكل. طبّق ترحيل الموارد البشرية أولًا: ' + e.toString(); });
    }
  }

  Future<void> _add(String kind) async {
    _code.clear(); _ar.clear(); _en.clear();
    final isLocation = kind == 'location';
    final isJob = kind == 'job';
    String? selectedDepartmentId;
    String? selectedGradeId;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: Text(isLocation ? 'إضافة موقع عمل' : isJob ? 'إضافة وظيفة' : 'إضافة إدارة أو قسم'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'الكود (حروف إنجليزية ثم أرقام)')),
        TextField(controller: _ar, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
        TextField(controller: _en, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
        if (isJob) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: selectedDepartmentId, isExpanded: true, decoration: const InputDecoration(labelText: 'الإدارة / القسم'), items: _departments.where((d) => d['is_active'] != false).map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['department_code'].toString() + ' • ' + d['name_ar'].toString()))).toList(), onChanged: (v) => setDialogState(() => selectedDepartmentId = v)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: selectedGradeId, isExpanded: true, decoration: const InputDecoration(labelText: 'الدرجة الوظيفية'), items: _grades.where((g) => g['is_active'] != false).map((g) => DropdownMenuItem<String>(value: g['id'].toString(), child: Text(g['grade_code'].toString() + ' • ' + g['name_ar'].toString()))).toList(), onChanged: (v) => setDialogState(() => selectedGradeId = v)),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
      ],
    )));
    if (saved != true || _code.text.trim().isEmpty || _ar.text.trim().isEmpty || _db == null) return;
    if (isJob && (selectedDepartmentId == null || selectedGradeId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الإدارة أو القسم والدرجة الوظيفية قبل حفظ الوظيفة.')));
      return;
    }
    try {
      if (isLocation) {
        await _db!.from('erp_hr_work_locations').insert({
          'company_id': _companyId, 'location_code': _code.text.trim().toUpperCase(),
          'name_ar': _ar.text.trim(), 'location_type': _code.text.toUpperCase().contains('CENT') ? 'central' : 'branch',
          'is_active': true,
        });
      } else if (isJob) {
        await _db!.from('erp_hr_jobs').insert({
          'company_id': _companyId, 'job_code': _code.text.trim().toUpperCase(),
          'name_ar': _ar.text.trim(), 'name_en': _en.text.trim(),
          'department_id': selectedDepartmentId,
          'grade_id': selectedGradeId,
          'min_qualification': 'إعدادية', 'min_license_class': '',
          'is_active': true,
        });
      } else {
        await _db!.from('erp_hr_departments').insert({
          'company_id': _companyId, 'department_code': _code.text.trim().toUpperCase(),
          'name_ar': _ar.text.trim(), 'name_en': _en.text.trim(), 'is_active': true,
        });
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: ' + e.toString())));
    }
  }

  Future<void> _edit(Map<String, dynamic> row, String kind) async {
    _code.text = row[kind == 'job' ? 'job_code' : kind == 'location' ? 'location_code' : 'department_code']?.toString() ?? '';
    _ar.text = row['name_ar']?.toString() ?? '';
    _en.text = row['name_en']?.toString() ?? '';
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('تعديل البيانات الأساسية'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'الكود')),
        TextField(controller: _ar, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
        TextField(controller: _en, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ التعديل')),
      ],
    ));
    if (saved != true || _code.text.trim().isEmpty || _ar.text.trim().isEmpty || _db == null) return;
    final table = kind == 'job' ? 'erp_hr_jobs' : kind == 'location' ? 'erp_hr_work_locations' : 'erp_hr_departments';
    final codeColumn = kind == 'job' ? 'job_code' : kind == 'location' ? 'location_code' : 'department_code';
    try {
      await _db!.from(table).update({
        codeColumn: _code.text.trim().toUpperCase(),
        'name_ar': _ar.text.trim(),
        if (kind != 'location') 'name_en': _en.text.trim(),
      }).eq('id', row['id']).eq('company_id', _companyId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تعديل السجل: ' + e.toString())));
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row, String kind) async {
    if (_db == null) return;
    final table = kind == 'job' ? 'erp_hr_jobs' : kind == 'location' ? 'erp_hr_work_locations' : 'erp_hr_departments';
    try {
      await _db!.from(table).update({'is_active': row['is_active'] != true}).eq('id', row['id']).eq('company_id', _companyId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تغيير الحالة: ' + e.toString())));
    }
  }

  Widget _recordCard(Map<String, dynamic> row, String codeKey, String nameKey, String kind) {
    final childDepartments = kind == 'department'
        ? _departments.where((d) => d['parent_id'] == row['id']).toList()
        : <Map<String, dynamic>>[];
    final ownJobs = _jobs.where((job) => job['department_id'] == row['id']).toList();
    final childWidgets = <Widget>[
      ...ownJobs.map((job) => ListTile(
        dense: true,
        leading: const Icon(Icons.work_outline, color: _hrStructureOrange),
        title: Text(job['job_code'].toString() + ' • ' + job['name_ar'].toString()),
        subtitle: Text('الدرجة: ' + (_grades.firstWhere((g) => g['id'] == job['grade_id'], orElse: () => <String,dynamic>{})['name_ar'] ?? 'غير محددة').toString()),
      )),
      ...childDepartments.map<Widget>((department) {
        final jobs = _jobs.where((job) => job['department_id'] == department['id']).toList();
        return ListTile(
          dense: true,
          leading: const Icon(Icons.subdirectory_arrow_left, color: _hrStructurePurple),
          title: Text(department['department_code'].toString() + ' • ' + department['name_ar'].toString()),
          subtitle: Text(jobs.map((job) => job['job_code'].toString() + ' • ' + job['name_ar'].toString()).join(' | ')),
        );
      }),
    ];
    return Card(
      child: ExpansionTile(
        leading: Icon(kind == 'location' ? Icons.location_on_outlined : kind == 'job' ? Icons.work_outline : Icons.account_tree_outlined, color: _hrStructureOrange),
        title: Text(row[codeKey].toString() + ' • ' + row[nameKey].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(row['is_active'] == false ? 'غير نشط' : 'نشط'),
        trailing: Wrap(spacing: 2, children: [
          IconButton(tooltip: 'تعديل', onPressed: () => _edit(row, kind), icon: const Icon(Icons.edit_outlined, color: _hrStructurePurple)),
          IconButton(tooltip: row['is_active'] == true ? 'إيقاف' : 'تنشيط', onPressed: () => _toggleActive(row, kind), icon: Icon(row['is_active'] == true ? Icons.pause_circle_outline : Icons.check_circle_outline, color: _hrStructureOrange)),
        ]),
        children: childWidgets,
      ),
    );
  }

  Widget _list(String title, List<Map<String, dynamic>> rows, String codeKey, String nameKey, String kind) {
    final cards = rows.map<Widget>((row) => _recordCard(row, codeKey, nameKey, kind)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
        FilledButton.icon(onPressed: () => _add(kind), icon: const Icon(Icons.add), label: const Text('إضافة')),
      ]),
      if (_loading) const LinearProgressIndicator(),
      Expanded(child: ListView(children: cards)),
    ]);
  }


  static const _documentColumns = <Map<String, String>>[
    {'key':'requires_photo','label':'صورة شخصية'},
    {'key':'requires_id_copy','label':'صورة بطاقة'},
    {'key':'requires_birth_certificate','label':'شهادة ميلاد'},
    {'key':'requires_qualification_certificate','label':'المؤهل'},
    {'key':'requires_work_card','label':'كعب العمل'},
    {'key':'requires_insurance_printout','label':'برنت تأمينات'},
    {'key':'requires_military_service','label':'موقف التجنيد'},
    {'key':'requires_criminal_record','label':'فيش جنائي'},
    {'key':'requires_trust_receipt','label':'إيصال أمانة'},
    {'key':'requires_health_certificate','label':'شهادة صحية'},
    {'key':'requires_driving_license','label':'رخصة قيادة'},
    {'key':'requires_bank_account','label':'حساب بنكي'},
  ];

  Widget _jobsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      const Expanded(child: Text('دليل الوظائف ومتطلبات التعيين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
      OutlinedButton.icon(onPressed: _addGrade, icon: const Icon(Icons.workspace_premium_outlined), label: const Text('إدارة الدرجات')),
      const SizedBox(width: 8),
      FilledButton.icon(onPressed: () => _add('job'), icon: const Icon(Icons.add), label: const Text('إضافة وظيفة')),
    ]),
    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('علامة ✓ تعني أن المستند مطلوب للتعيين. لتعديل المتطلبات اضغط زر التعديل في آخر الصف.', style: TextStyle(color: Colors.black54))),
    if (_loading) const LinearProgressIndicator(),
    Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
      columns: [
        const DataColumn(label: Text('كود الوظيفة')), const DataColumn(label: Text('الوظيفة')),
        const DataColumn(label: Text('الإدارة / القسم')), const DataColumn(label: Text('الدرجة')),
        const DataColumn(label: Text('أقل مؤهل')), const DataColumn(label: Text('أقل رخصة')),
        ..._documentColumns.map((d) => DataColumn(label: SizedBox(width: 82, child: Text(d['label']!, textAlign: TextAlign.center)))),
        const DataColumn(label: Text('تعديل')),
      ],
      rows: _jobs.map((j) => DataRow(cells: [
        DataCell(Text((j['job_code'] ?? '').toString())),
        DataCell(SizedBox(width: 170, child: Text((j['name_ar'] ?? '').toString()))),
        DataCell(SizedBox(width: 160, child: Text((_departments.firstWhere((d) => d['id'] == j['department_id'], orElse: () => <String,dynamic>{})['name_ar'] ?? 'غير محدد').toString()))),
        DataCell(SizedBox(width: 125, child: Text((_grades.firstWhere((g) => g['id'] == j['grade_id'], orElse: () => <String,dynamic>{})['name_ar'] ?? 'غير محدد').toString()))),
        DataCell(Text((j['min_qualification'] ?? '—').toString())),
        DataCell(Text((j['min_license_class'] ?? 'لا يشترط').toString())),
        ..._documentColumns.map((d) => DataCell(Center(child: Checkbox(value: j[d['key']] == true, visualDensity: VisualDensity.compact, onChanged: (value) => _toggleJobRequirement(j, d['key']!, value == true)))),
        DataCell(IconButton(tooltip: 'تعديل متطلبات الوظيفة', onPressed: () => _editJobRequirements(j), icon: const Icon(Icons.edit_outlined, color: _hrStructurePurple))),
      ])).toList(),
    )))),
  ]);

  Widget _gradesView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      const Expanded(child: Text('درجات الوظائف والتدرج الوظيفي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
      FilledButton.icon(onPressed: _addGrade, icon: const Icon(Icons.add), label: const Text('إضافة درجة')),
    ]),
    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('الدرجات مرتبة من القيادات العليا إلى الوظائف المساندة.', style: TextStyle(color: Colors.black54))),
    Expanded(child: ListView(children: _grades.map((g) => Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFFF5EFFB), child: Text((g['rank_order'] ?? '').toString())),
      title: Text((g['grade_code'].toString() + ' • ' + g['name_ar'].toString()), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text((g['name_en'] ?? '').toString()),
      trailing: TextButton.icon(onPressed: () => _editGrade(g), icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')),
    ))).toList())),
  ]);

  Future<void> _addGrade() async {
    _code.clear(); _ar.clear(); _en.clear();
    final rank = TextEditingController(text: (_grades.length + 1).toString());
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إضافة درجة وظيفية'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'كود الدرجة مثل GRD-015')),
        TextField(controller: _ar, decoration: const InputDecoration(labelText: 'اسم الدرجة بالعربية')),
        TextField(controller: _en, decoration: const InputDecoration(labelText: 'اسم الدرجة بالإنجليزية')),
        TextField(controller: rank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ترتيب الدرجة')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    ));
    if (saved == true && _code.text.trim().isNotEmpty && _ar.text.trim().isNotEmpty && _db != null) {
      try {
        await _db!.from('erp_hr_job_grades').insert({'company_id':_companyId,'grade_code':_code.text.trim().toUpperCase(),'name_ar':_ar.text.trim(),'name_en':_en.text.trim(),'rank_order':int.tryParse(rank.text) ?? _grades.length + 1,'is_active':true});
        await _load();
      } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الدرجة: ' + e.toString()))); }
    }
    rank.dispose();
  }

  Future<void> _editGrade(Map<String,dynamic> grade) async {
    _code.text = (grade['grade_code'] ?? '').toString(); _ar.text = (grade['name_ar'] ?? '').toString(); _en.text = (grade['name_en'] ?? '').toString();
    final rank = TextEditingController(text: (grade['rank_order'] ?? 1).toString());
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تعديل الدرجة الوظيفية'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'كود الدرجة')),
        TextField(controller: _ar, decoration: const InputDecoration(labelText: 'اسم الدرجة بالعربية')),
        TextField(controller: _en, decoration: const InputDecoration(labelText: 'اسم الدرجة بالإنجليزية')),
        TextField(controller: rank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ترتيب الدرجة')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ التعديل'))],
    ));
    if (saved == true && _code.text.trim().isNotEmpty && _ar.text.trim().isNotEmpty && _db != null) {
      try {
        await _db!.from('erp_hr_job_grades').update({'grade_code':_code.text.trim().toUpperCase(),'name_ar':_ar.text.trim(),'name_en':_en.text.trim(),'rank_order':int.tryParse(rank.text) ?? 1}).eq('id',grade['id']).eq('company_id',_companyId);
        await _load();
      } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تعديل الدرجة: ' + e.toString()))); }
    }
    rank.dispose();
  }

  Future<void> _toggleJobRequirement(Map<String,dynamic> job, String key, bool value) async {
    if (_db == null) return;
    try {
      await _db!.from('erp_hr_jobs').update({key:value}).eq('id',job['id']).eq('company_id',_companyId);
      await _load();
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحديث متطلب التعيين: ' + e.toString())));
    }
  }

  Future<void> _editJobRequirements(Map<String,dynamic> job) async {
    var gradeId = job['grade_id']?.toString();
    var departmentId = job['department_id']?.toString();
    var qualification = (job['min_qualification'] ?? 'إعدادية').toString();
    var license = (job['min_license_class'] ?? '').toString();
    final required = <String,bool>{for(final d in _documentColumns) d['key']!: job[d['key']] == true};
    const qualifications = ['بدون مؤهل','ابتدائية','إعدادية','ثانوية عامة','دبلوم فني','تجارة / ثانوية','جامعية','تجارة / جامعية','مؤهل متخصص'];
    const licenses = ['', 'مهنية','ثالثة مهنية','ثانية مهنية','أولى مهنية','خاصة','دراجة نارية'];
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx,setDialogState) => AlertDialog(
      title: Text('متطلبات وظيفة: ' + (job['name_ar'] ?? '').toString()),
      content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: _departments.any((d)=>d['id'].toString()==departmentId) ? departmentId : null, isExpanded:true, decoration: const InputDecoration(labelText:'الإدارة / القسم'), items:_departments.where((d)=>d['is_active'] != false).map((d)=>DropdownMenuItem<String>(value:d['id'].toString(),child:Text(d['department_code'].toString()+' • '+d['name_ar'].toString()))).toList(), onChanged:(v)=>setDialogState(()=>departmentId=v)),
        DropdownButtonFormField<String>(value: _grades.any((g)=>g['id'].toString()==gradeId) ? gradeId : null, isExpanded:true, decoration: const InputDecoration(labelText:'الدرجة الوظيفية'), items:_grades.map((g)=>DropdownMenuItem<String>(value:g['id'].toString(),child:Text(g['grade_code'].toString()+' • '+g['name_ar'].toString()))).toList(), onChanged:(v)=>setDialogState(()=>gradeId=v)),
        DropdownButtonFormField<String>(value: qualifications.contains(qualification)?qualification:qualifications[2], isExpanded:true, decoration:const InputDecoration(labelText:'أقل مؤهل مطلوب'), items:qualifications.map((q)=>DropdownMenuItem<String>(value:q,child:Text(q))).toList(), onChanged:(v)=>setDialogState(()=>qualification=v ?? qualifications[2])),
        DropdownButtonFormField<String>(value: licenses.contains(license)?license:'', isExpanded:true, decoration:const InputDecoration(labelText:'أقل درجة رخصة مطلوبة'), items:licenses.map((q)=>DropdownMenuItem<String>(value:q,child:Text(q.isEmpty?'لا يشترط رخصة':q))).toList(), onChanged:(v)=>setDialogState(()=>license=v ?? '')),
        const Align(alignment:Alignment.centerRight, child:Padding(padding:EdgeInsets.only(top:12,bottom:6),child:Text('المسوغات المطلوبة للتعيين',style:TextStyle(fontWeight:FontWeight.w900,color:_hrStructurePurple)))),
        ..._documentColumns.map((d)=>CheckboxListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(d['label']!),value:required[d['key']] == true,onChanged:(v)=>setDialogState(()=>required[d['key']!]=v==true))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ المتطلبات'))],
    )));
    if(saved==true && _db!=null){
      try {
        await _db!.from('erp_hr_jobs').update({'department_id':departmentId,'grade_id':gradeId,'min_qualification':qualification,'min_license_class':license,...required}).eq('id',job['id']).eq('company_id',_companyId);
        await _load();
      } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ متطلبات الوظيفة: ' + e.toString()))); }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      const Align(alignment: Alignment.centerRight, child: Text('الهيكل التنظيمي والوظائف ومواقع العمل', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
      if (_error != null) Align(alignment: Alignment.centerRight, child: Text(_error!, style: const TextStyle(color: Colors.red))),
      TabBar(controller: _tabs, isScrollable: true, labelColor: _hrStructurePurple, indicatorColor: _hrStructureOrange, tabs: const [
        Tab(text: 'الإدارات والأقسام'), Tab(text: 'الوظائف ومتطلبات التعيين'), Tab(text: 'درجات الوظائف'), Tab(text: 'مواقع العمل'),
      ]),
      Expanded(child: TabBarView(controller: _tabs, children: [
        _list('شجرة الإدارات والأقسام', _departments.where((d) => d['parent_id'] == null && d['department_level'] != 'section').toList(), 'department_code', 'name_ar', 'department'),
        _jobsView(), _gradesView(),
        _list('مواقع العمل', _locations, 'location_code', 'name_ar', 'location'),
      ])),
    ])),
  );
}
