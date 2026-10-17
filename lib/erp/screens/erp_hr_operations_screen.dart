import 'package:flutter/material.dart';
import '../services/erp_hr_repository.dart';

class ErpHrOperationsScreen extends StatefulWidget {
  const ErpHrOperationsScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;

  @override
  State<ErpHrOperationsScreen> createState() => _ErpHrOperationsScreenState();
}

class _ErpHrOperationsScreenState extends State<ErpHrOperationsScreen> {
  final _repo = ErpHrRepository();
  final _company = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _attendance = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;
  String _view = 'employees';

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
  }

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString();

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولًا.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final values = await Future.wait([
        _repo.fetchEmployees(_company.text),
        _repo.fetchAttendance(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = values[0];
        _attendance = values[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل بيانات الموارد البشرية: $e'; });
    }
  }

  Future<void> _addEmployee() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    final job = TextEditingController();
    final dept = TextEditingController();
    final salary = TextEditingController(text: '0');
    String? localError;
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('إضافة موظف'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'كود الموظف *')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الموظف *')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
            TextField(controller: job, decoration: const InputDecoration(labelText: 'المسمى الوظيفي')),
            TextField(controller: dept, decoration: const InputDecoration(labelText: 'الإدارة / القسم')),
            TextField(controller: salary, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الراتب الأساسي')),
            if (localError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(localError!, style: const TextStyle(color: Colors.red))),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            final amount = double.tryParse(salary.text.trim());
            if (code.text.trim().isEmpty || name.text.trim().isEmpty || amount == null || amount < 0) {
              refresh(() => localError = 'راجع كود الموظف والاسم والراتب.');
              return;
            }
            Navigator.pop(ctx);
            setState(() { _saving = true; _error = null; });
            try {
              await _repo.addEmployee(companyId: _company.text, employeeCode: code.text,
                fullName: name.text, phone: phone.text, jobTitle: job.text,
                department: dept.text, baseSalary: amount);
              if (!mounted) return;
              setState(() { _saving = false; _message = 'تمت إضافة الموظف.'; });
              await _load();
            } catch (e) {
              if (!mounted) return;
              setState(() { _saving = false; _error = 'تعذرت إضافة الموظف: $e'; });
            }
          }, child: const Text('حفظ الموظف')),
        ],
      )));
    code.dispose(); name.dispose(); phone.dispose(); job.dispose(); dept.dispose(); salary.dispose();
  }

  Future<void> _checkIn(Map<String, dynamic> employee) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.checkIn(companyId: _company.text, employeeId: _s(employee['id']));
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تسجيل حضور ${_s(employee['full_name'])}.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تسجيل الحضور: $e'; });
    }
  }

  Future<void> _checkOut(Map<String, dynamic> record) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.checkOut(_s(record['id']));
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم تسجيل الانصراف.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر تسجيل الانصراف: $e'; });
    }
  }

  String _employeeName(String id) {
    final matches = _employees.where((e) => _s(e['id']) == id);
    return matches.isEmpty ? id : '${_s(matches.first['employee_code'])} — ${_s(matches.first['full_name'])}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateLabel = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final presentIds = _attendance.map((r) => _s(r['employee_id'])).toSet();
    final activeEmployees = _employees.where((e) => _s(e['employment_status']) == 'active' && e['is_active'] != false).toList();
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('الموارد البشرية', style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('دليل الموظفين وتسجيل الحضور والانصراف اليومي. صلاحيات الرواتب منفصلة عن صلاحيات التشغيل.',
          style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل البيانات')),
          OutlinedButton.icon(onPressed: _saving || _company.text.trim().isEmpty ? null : _addEmployee, icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة موظف')),
        ]),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        if (_loading || _saving) const LinearProgressIndicator(),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'employees', label: Text('الموظفون'), icon: Icon(Icons.badge_outlined)),
            ButtonSegment(value: 'attendance', label: Text('الحضور اليوم'), icon: Icon(Icons.access_time)),
          ],
          selected: {_view},
          onSelectionChanged: (v) => setState(() => _view = v.first),
        ),
        const SizedBox(height: 10),
        if (_view == 'employees') ...[
          Text('دليل الموظفين • ${_employees.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (_employees.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد بيانات موظفين محمّلة.')),
          ..._employees.map((e) => Card(child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFF0E8FA), child: Icon(Icons.person, color: Color(0xFF3E007D))),
            title: Text('${_s(e['employee_code'])} — ${_s(e['full_name'])}'),
            subtitle: Text('${_s(e['job_title']).isEmpty ? 'بدون مسمى وظيفي' : _s(e['job_title'])} • ${_s(e['department_name'])}\nالحالة: ${_s(e['employment_status'])}'),
            isThreeLine: true,
          ))),
        ] else ...[
          Text('الحضور والانصراف • $dateLabel', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          if (_employees.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('حمّل دليل الموظفين أولًا.')),
          ...activeEmployees.where((e) => !presentIds.contains(_s(e['id']))).map((e) => Card(child: ListTile(
            title: Text(_employeeName(_s(e['id']))),
            subtitle: const Text('لم يسجل حضور اليوم'),
            trailing: FilledButton(onPressed: _saving ? null : () => _checkIn(e), child: const Text('تسجيل حضور')),
          ))),
          ..._attendance.map((r) {
            final checkedOut = _s(r['check_out']).isNotEmpty;
            return Card(child: ListTile(
              leading: Icon(checkedOut ? Icons.check_circle : Icons.timelapse, color: checkedOut ? Colors.green : const Color(0xFFFFA015)),
              title: Text(_employeeName(_s(r['employee_id']))),
              subtitle: Text('حضور: ${_s(r['check_in']).isEmpty ? '—' : _s(r['check_in']).replaceFirst('T', ' ')}\nانصراف: ${checkedOut ? _s(r['check_out']).replaceFirst('T', ' ') : 'لم يسجل بعد'}'),
              isThreeLine: true,
              trailing: checkedOut ? const Icon(Icons.verified, color: Colors.green) : OutlinedButton(onPressed: _saving ? null : () => _checkOut(r), child: const Text('تسجيل انصراف')),
            ));
          }),
        ],
      ],
    ));
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
