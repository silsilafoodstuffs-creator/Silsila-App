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
  List<Map<String, dynamic>> _locations = [];
  String? _error;
  bool _loading = false;

  SupabaseClient? get _db { try { return Supabase.instance.client; } catch (_) { return null; } }
  String get _companyId => (widget.initialCompanyId ?? '').trim();

  @override
  void initState() {
    super.initState();
    final index = widget.initialTab == 'مواقع العمل' ? 2 : widget.initialTab == 'الوظائف والدرجات' ? 1 : 0;
    _tabs = TabController(length: 3, vsync: this, initialIndex: index);
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
        _db!.from('erp_hr_work_locations').select().eq('company_id', _companyId).order('location_code'),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = List<Map<String, dynamic>>.from(result[0]);
        _jobs = List<Map<String, dynamic>>.from(result[1]);
        _locations = List<Map<String, dynamic>>.from(result[2]);
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
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(isLocation ? 'إضافة موقع عمل' : isJob ? 'إضافة وظيفة' : 'إضافة إدارة أو قسم'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, decoration: const InputDecoration(labelText: 'الكود (حروف إنجليزية ثم أرقام)')),
        TextField(controller: _ar, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
        TextField(controller: _en, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
      ],
    ));
    if (saved != true || _code.text.trim().isEmpty || _ar.text.trim().isEmpty || _db == null) return;
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
          'name_ar': _ar.text.trim(), 'name_en': _en.text.trim(), 'is_active': true,
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

  Widget _recordCard(Map<String, dynamic> row, String codeKey, String nameKey, String kind) {
    final childDepartments = kind == 'department'
        ? _departments.where((d) => d['parent_id'] == row['id']).toList()
        : <Map<String, dynamic>>[];
    final childWidgets = childDepartments.map<Widget>((department) {
      final jobs = _jobs.where((job) => job['department_id'] == department['id']).toList();
      return ListTile(
        dense: true,
        leading: const Icon(Icons.subdirectory_arrow_left, color: _hrStructurePurple),
        title: Text(department['department_code'].toString() + ' • ' + department['name_ar'].toString()),
        subtitle: Text(jobs.map((job) => job['job_code'].toString() + ' • ' + job['name_ar'].toString()).join(' | ')),
      );
    }).toList();
    return Card(
      child: ExpansionTile(
        leading: Icon(kind == 'location' ? Icons.location_on_outlined : kind == 'job' ? Icons.work_outline : Icons.account_tree_outlined, color: _hrStructureOrange),
        title: Text(row[codeKey].toString() + ' • ' + row[nameKey].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(row['is_active'] == false ? 'غير نشط' : 'نشط'),
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

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      const Align(alignment: Alignment.centerRight, child: Text('الهيكل التنظيمي والوظائف ومواقع العمل', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _hrStructurePurple))),
      if (_error != null) Align(alignment: Alignment.centerRight, child: Text(_error!, style: const TextStyle(color: Colors.red))),
      TabBar(controller: _tabs, labelColor: _hrStructurePurple, indicatorColor: _hrStructureOrange, tabs: const [
        Tab(text: 'الإدارات والأقسام'), Tab(text: 'الوظائف والدرجات'), Tab(text: 'مواقع العمل'),
      ]),
      Expanded(child: TabBarView(controller: _tabs, children: [
        _list('شجرة الإدارات والأقسام', _departments.where((d) => d['parent_id'] == null && d['department_level'] != 'section').toList(), 'department_code', 'name_ar', 'department'),
        _list('دليل الوظائف', _jobs, 'job_code', 'name_ar', 'job'),
        _list('مواقع العمل', _locations, 'location_code', 'name_ar', 'location'),
      ])),
    ])),
  );
}
