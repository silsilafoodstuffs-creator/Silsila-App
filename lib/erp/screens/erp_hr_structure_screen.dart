import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/erp_quick_task_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hrStructurePurple = Color(0xFF3E007D);
const _hrStructureOrange = Color(0xFFFFA015);

class ErpHrStructureScreen extends StatefulWidget {
  const ErpHrStructureScreen({super.key, this.initialCompanyId, this.initialTab, this.initialView = 'tree', this.onViewChanged});
  final String? initialCompanyId;
  final String? initialTab;
  final String initialView;
  final ValueChanged<String>? onViewChanged;
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
  late String _viewMode = widget.initialView;

  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String get _companyId => (widget.initialCompanyId ?? '').trim();

  @override
  void initState() {
    super.initState();
    final departmentMode = widget.initialTab == 'مواقع العمل' || widget.initialTab == 'الإدارات والأقسام';
    final index = departmentMode ? (widget.initialTab == 'مواقع العمل' ? 1 : 0)
        : widget.initialTab == 'درجات الوظائف' ? 2 : widget.initialTab == 'متطلبات التعيين' ? 1 : 0;
    _tabs = TabController(length: departmentMode ? 2 : 3, vsync: this, initialIndex: index);
    _tabs.addListener(_onTabChanged);
    _load();
  }
  void _onTabChanged() { if (mounted && !_tabs.indexIsChanging) setState(() {}); }

  @override
  void didUpdateWidget(covariant ErpHrStructureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialView != widget.initialView) _viewMode = widget.initialView;
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged); _tabs.dispose(); _code.dispose(); _ar.dispose(); _en.dispose(); super.dispose();
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
    String? selectedParentId;
    String selectedDepartmentLevel = 'directorate';
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: Text(isLocation ? 'إضافة موقع عمل' : isJob ? 'إضافة وظيفة' : 'إضافة إدارة أو قسم'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'الكود (حروف إنجليزية ثم أرقام)')),
        TextField(controller: _ar, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
        TextField(controller: _en, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
        if (!isJob && !isLocation) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: selectedDepartmentLevel, isExpanded: true, decoration: const InputDecoration(labelText: 'نوع المستوى التنظيمي'), items: const [DropdownMenuItem(value: 'directorate', child: Text('إدارة رئيسية')), DropdownMenuItem(value: 'department', child: Text('إدارة فرعية')), DropdownMenuItem(value: 'section', child: Text('قسم'))], onChanged: (v) => setDialogState(() { selectedDepartmentLevel = v ?? 'directorate'; if (selectedDepartmentLevel == 'directorate') selectedParentId = null; })),
          if (selectedDepartmentLevel != 'directorate') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: selectedParentId, isExpanded: true, decoration: const InputDecoration(labelText: 'يتبع الإدارة / القسم'), items: _departments.where((d) => d['department_level'] != 'section' && d['is_active'] != false).map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text(d['department_code'].toString() + ' • ' + d['name_ar'].toString()))).toList(), onChanged: (v) => setDialogState(() => selectedParentId = v)),
          ],
        ],
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
    if (!isJob && !isLocation && selectedDepartmentLevel != 'directorate' && selectedParentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الإدارة الأب للقسم أو الإدارة الفرعية.')));
      return;
    }
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
          'name_ar': _ar.text.trim(), 'name_en': _en.text.trim(),
          'department_level': selectedDepartmentLevel,
          'parent_id': selectedDepartmentLevel == 'directorate' ? null : selectedParentId,
          'is_active': true,
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


  Widget _departmentTreeNode(Map<String, dynamic> row) {
    final children = _departments.where((d) => d['parent_id']?.toString() == row['id']?.toString()).toList()
      ..sort((a, b) => (a['department_code'] ?? '').toString().compareTo((b['department_code'] ?? '').toString()));
    final jobs = _jobs.where((j) => j['department_id']?.toString() == row['id']?.toString()).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ExpansionTile(
        key: PageStorageKey<String>('hr-department-${row['id']}'),
        initiallyExpanded: true,
        leading: Icon(
          row['department_level'] == 'directorate' ? Icons.account_balance_outlined : row['department_level'] == 'section' ? Icons.segment : Icons.account_tree_outlined,
          color: row['is_active'] == false ? Colors.grey : _hrStructureOrange,
        ),
        title: Text('${row['department_code'] ?? ''} • ${row['name_ar'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${row['department_level'] == 'directorate' ? 'إدارة رئيسية' : row['department_level'] == 'section' ? 'قسم' : 'إدارة فرعية'} • ${row['is_active'] == false ? 'غير نشط' : 'نشط'}'),
        trailing: Wrap(spacing: 0, children: [
          IconButton(tooltip: 'تعديل', onPressed: () => _edit(row, 'department'), icon: const Icon(Icons.edit_outlined, color: _hrStructurePurple)),
          IconButton(tooltip: row['is_active'] == true ? 'إيقاف' : 'تنشيط', onPressed: () => _toggleActive(row, 'department'), icon: Icon(row['is_active'] == true ? Icons.pause_circle_outline : Icons.check_circle_outline, color: _hrStructureOrange)),
        ]),
        children: [
          ...children.map(_departmentTreeNode),
          ...jobs.map((j) => ListTile(
            dense: true,
            contentPadding: const EdgeInsetsDirectional.only(start: 48, end: 16),
            leading: const Icon(Icons.work_outline, color: _hrStructurePurple),
            title: Text('${j['job_code'] ?? ''} • ${j['name_ar'] ?? ''}'),
            subtitle: Text('الدرجة: ${_grades.firstWhere((g) => g['id']?.toString() == j['grade_id']?.toString(), orElse: () => <String, dynamic>{})['name_ar'] ?? 'غير محددة'}'),
          )),
          if (children.isEmpty && jobs.isEmpty)
            const ListTile(dense: true, leading: Icon(Icons.info_outline, color: Colors.black38), title: Text('لا توجد أقسام فرعية أو وظائف مسجلة تحت هذا العنصر')),
        ],
      ),
    );
  }

  Widget _departmentsView() {
    final roots = _departments.where((d) => d['parent_id'] == null).toList()
      ..sort((a, b) => (a['department_code'] ?? '').toString().compareTo((b['department_code'] ?? '').toString()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(_viewMode == 'tree' ? 'شجرة الإدارات والأقسام' : 'جدول الإدارات والأقسام', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
        Text('${_departments.length} سجل', style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 10),
        FilledButton.icon(onPressed: () => _add('department'), icon: const Icon(Icons.add), label: const Text('إضافة')),
        IconButton(tooltip: 'إعادة تحميل البيانات', onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      Expanded(child: _viewMode == 'tree'
        ? roots.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.account_tree_outlined, size: 44, color: _hrStructureOrange),
              const SizedBox(height: 8),
              Text(_departments.isEmpty ? 'لا توجد بيانات إدارات محمّلة لهذه الشركة.' : 'لا توجد إدارات رئيسية؛ راجع علاقة الإدارة الأب والمستوى التنظيمي.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة تحميل')),
            ]))
          : ListView(children: roots.map(_departmentTreeNode).toList())
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
            columns: const [
              DataColumn(label: Text('الكود')), DataColumn(label: Text('اسم الإدارة / القسم')),
              DataColumn(label: Text('المستوى')), DataColumn(label: Text('يتبع')),
              DataColumn(label: Text('الحالة')), DataColumn(label: Text('إجراءات')),
            ],
            rows: _departments.map((d) {
              final parent = _departments.firstWhere((p) => p['id']?.toString() == d['parent_id']?.toString(), orElse: () => <String, dynamic>{});
              final level = d['department_level'] == 'directorate' ? 'إدارة رئيسية' : d['department_level'] == 'section' ? 'قسم' : 'إدارة فرعية';
              return DataRow(cells: [
                DataCell(Text((d['department_code'] ?? '').toString())),
                DataCell(SizedBox(width: 220, child: Text((d['name_ar'] ?? '').toString()))),
                DataCell(Text(level)),
                DataCell(SizedBox(width: 180, child: Text((parent['name_ar'] ?? '—').toString()))),
                DataCell(Text(d['is_active'] == false ? 'غير نشط' : 'نشط')),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'تعديل', onPressed: () => _edit(d, 'department'), icon: const Icon(Icons.edit_outlined, color: _hrStructurePurple)),
                  IconButton(tooltip: d['is_active'] == true ? 'إيقاف' : 'تنشيط', onPressed: () => _toggleActive(d, 'department'), icon: const Icon(Icons.toggle_on_outlined, color: _hrStructureOrange)),
                ])),
              ]);
            }).toList(),
          )))),
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

  Widget _jobsCatalogView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [
      const Expanded(child: Text('دليل الوظائف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
      FilledButton.icon(onPressed: () => _add('job'), icon: const Icon(Icons.add), label: const Text('إضافة وظيفة')),
      IconButton(tooltip: 'تحديث', onPressed: _load, icon: const Icon(Icons.refresh)),
    ]),
    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('الوظائف المسجلة وربط كل وظيفة بالإدارة والدرجة الوظيفية.')),
    Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
      columns: const [
        DataColumn(label: Text('م')), DataColumn(label: Text('كود الوظيفة')),
        DataColumn(label: Text('اسم الوظيفة')), DataColumn(label: Text('الإدارة / القسم')),
        DataColumn(label: Text('الدرجة')), DataColumn(label: Text('الحالة')),
        DataColumn(label: Text('متطلبات التعيين')),
      ],
      rows: List.generate(_jobs.length, (index) {
        final job = _jobs[index];
        final department = _departments.where((d) => d['id']?.toString() == job['department_id']?.toString());
        final grade = _grades.where((g) => g['id']?.toString() == job['grade_id']?.toString());
        return DataRow(cells: [
          DataCell(Text((index + 1).toString())),
          DataCell(Text((job['job_code'] ?? '').toString())),
          DataCell(Text((job['name_ar'] ?? '').toString())),
          DataCell(Text(department.isEmpty ? '—' : (department.first['name_ar'] ?? '').toString())),
          DataCell(Text(grade.isEmpty ? '—' : (grade.first['name_ar'] ?? '').toString())),
          DataCell(Text(job['is_active'] == true ? 'نشط' : 'موقوف')),
          DataCell(IconButton(tooltip: 'عرض وتعديل متطلبات التعيين', onPressed: () => _editJobRequirements(job), icon: const Icon(Icons.fact_check_outlined, color: _hrStructurePurple))),
        ]);
      }),
    )))),
  ]);

  Widget _jobRequirementsView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
        ..._documentColumns.map((d) => DataCell(Center(child: Checkbox(value: j[d['key']] == true, visualDensity: VisualDensity.compact, onChanged: (value) => _toggleJobRequirement(j, d['key']!, value == true))))),
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


  bool get _departmentMode => widget.initialTab == 'مواقع العمل' || widget.initialTab == 'الإدارات والأقسام';
  List<Map<String,dynamic>> get _quickRows {
    if (_departmentMode) return _tabs.index==0 ? _departments : _locations;
    return _tabs.index==2 ? _grades : _jobs;
  }
  String get _quickKind {
    if (_departmentMode) return _tabs.index==0 ? 'department' : 'location';
    return _tabs.index==2 ? 'grade' : 'job';
  }
  String _quickCode(Map<String,dynamic> row) => (row[_quickKind=='department'?'department_code':_quickKind=='location'?'location_code':_quickKind=='grade'?'grade_code':'job_code']??'').toString();
  String _quickName(Map<String,dynamic> row) => (row['name_ar']??'').toString();
  Future<void> _quickAdd() async {
    switch(_quickKind){case 'department':await _add('department');break;case 'location':await _add('location');break;case 'grade':await _addGrade();break;default:await _add('job');}
  }
  Future<void> _quickEdit() async {
    if(_quickRows.isEmpty)return;
    final row=_quickRows.first;
    if(_quickKind=='grade'){await _editGrade(row);}
    else if(!_departmentMode && _tabs.index==1){await _editJobRequirements(row);}
    else{await _edit(row,_quickKind);}
  }
  Future<void> _quickDelete() async {
    if(_quickRows.isEmpty)return;
    final row=_quickRows.first;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('تأكيد إيقاف السجل'),
      content:Text('هل تريد إيقاف «${_quickName(row)}»؟ لن يتم حذف السجل المرتبط ببيانات أخرى.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لا')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('نعم، إيقاف'))],
    ));
    if(yes!=true||_db==null)return;
    try{
      final table=_quickKind=='department'?'erp_hr_departments':_quickKind=='location'?'erp_hr_work_locations':_quickKind=='grade'?'erp_hr_job_grades':'erp_hr_jobs';
      await _db!.from(table).update({'is_active':false}).eq('id',row['id']).eq('company_id',_companyId);
      await _load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إيقاف السجل: $e')));}
  }
  void _quickPreview() {
    final rows=_quickRows;
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('معاينة بيانات الشاشة'),
      content:SizedBox(width:560,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('عدد السجلات: ${rows.length}',style:const TextStyle(fontWeight:FontWeight.w800)),
        ...rows.take(100).map((r)=>ListTile(dense:true,title:Text(_quickCode(r)+' — '+_quickName(r)),subtitle:Text(r['is_active']==true?'نشط':'موقوف'))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
    ));
  }
  Future<void> _quickPdf({required bool share}) async {
    final rows=_quickRows;
    if(rows.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد بيانات للتصدير.')));return;}
    try{
      final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      final doc=pw.Document();
      doc.addPage(pw.MultiPage(theme:pw.ThemeData.withFont(base:font,bold:font),build:(_)=>[
        pw.Text('Silsila • ${_quickKind=='department'?'بيانات الإدارات':_quickKind=='location'?'مواقع العمل':_quickKind=='grade'?'درجات الوظائف':'بيانات الوظائف'}',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:10),
        pw.TableHelper.fromTextArray(headers:const ['م','الكود','الاسم','الحالة'],data:rows.asMap().entries.map((e)=>[e.key+1,_quickCode(e.value),_quickName(e.value),e.value['is_active']==true?'نشط':'موقوف']).toList()),
      ]));
      final bytes=await doc.save();
      if(share){await Printing.sharePdf(bytes:bytes,filename:'Silsila-HR-Structure.pdf');}
      else{await Printing.layoutPdf(onLayout:(_)=>Future.value(bytes));}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إنشاء PDF: $e')));}
  }
  Future<void> _quickExcel() async {
    final rows=_quickRows;
    if(rows.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا توجد بيانات للتصدير.')));return;}
    try{
      final book=excel.Excel.createExcel();
      final sheet=book['بيانات'];
      sheet.appendRow([excel.TextCellValue('م'),excel.TextCellValue('الكود'),excel.TextCellValue('الاسم'),excel.TextCellValue('الحالة')]);
      for(var i=0;i<rows.length;i++){final r=rows[i];sheet.appendRow([excel.IntCellValue(i+1),excel.TextCellValue(_quickCode(r)),excel.TextCellValue(_quickName(r)),excel.TextCellValue(r['is_active']==true?'نشط':'موقوف')]);}
      final bytes=book.encode();
      if(bytes==null)throw StateError('تعذر تجهيز ملف Excel.');
      final saved=await FilePicker.platform.saveFile(dialogTitle:'حفظ بيانات الهيكل الوظيفي',fileName:'Silsila-HR-Structure.xlsx',bytes:Uint8List.fromList(bytes));
      if(saved!=null&&mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تجهيز ملف Excel.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تصدير Excel: $e')));}
  }
  Widget _quickToolbar()=>SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
    ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh,onPressed:_loading?null:_load),
    ErpQuickTaskButton(label:'إضافة',icon:Icons.add,onPressed:_loading?null:_quickAdd),
    ErpQuickTaskButton(label:'حفظ',icon:Icons.save,onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('يتم حفظ البيانات مباشرة عند تأكيد نافذة الإضافة أو التعديل.')))),
    ErpQuickTaskButton(label:'تعديل',icon:Icons.edit,onPressed:_quickRows.isEmpty?null:_quickEdit),
    ErpQuickTaskButton(label:'حذف',icon:Icons.delete,onPressed:_quickRows.isEmpty?null:_quickDelete),
    ErpQuickTaskButton(label:'معاينة',icon:Icons.visibility,onPressed:_quickPreview),
    ErpQuickTaskButton(label:'طباعة',icon:Icons.print,onPressed:()=>_quickPdf(share:false)),
    ErpQuickTaskButton(label:'Excel',icon:Icons.file_download,onPressed:_quickExcel),
    ErpQuickTaskButton(label:'PDF',icon:Icons.picture_as_pdf,onPressed:()=>_quickPdf(share:true)),
  ]));

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      const Align(alignment: Alignment.centerRight, child: Text('الهيكل التنظيمي والوظائف ومواقع العمل', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
      _quickToolbar(),
      if (_error != null) Align(alignment: Alignment.centerRight, child: Text(_error!, style: const TextStyle(color: Colors.red))),
      TabBar(controller: _tabs, isScrollable: true, labelColor: _hrStructurePurple, indicatorColor: _hrStructureOrange, tabs: widget.initialTab == 'مواقع العمل' || widget.initialTab == 'الإدارات والأقسام' ? const [
        Tab(text: 'الإدارات والأقسام'), Tab(text: 'مواقع العمل'),
      ] : const [
        Tab(text: 'الوظائف'), Tab(text: 'متطلبات التعيين'), Tab(text: 'درجات الوظائف'),
      ]),
      Expanded(child: TabBarView(controller: _tabs, children: widget.initialTab == 'مواقع العمل' || widget.initialTab == 'الإدارات والأقسام' ? [
        _departmentsView(), _list('مواقع العمل', _locations, 'location_code', 'name_ar', 'location'),
      ] : [
        _jobsCatalogView(), _jobRequirementsView(), _gradesView(),
      ])),
    ])),
  );
}
