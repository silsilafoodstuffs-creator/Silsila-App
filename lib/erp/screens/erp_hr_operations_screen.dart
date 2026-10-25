import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
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
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;
  String _view = 'employees';

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
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
        _repo.fetchLeaveRequests(_company.text),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = values[0];
        _attendance = values[1];
        _leaveRequests = values[2];
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
    final nationalId = TextEditingController();
    final job = TextEditingController();
    final dept = TextEditingController();
    final salary = TextEditingController(text: '0');
    String? localError;
    bool nationalIdRequired = true;
    try {
      nationalIdRequired = await _repo.isNationalIdRequired(_company.text);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر قراءة سياسة الرقم القومي: $e');
      code.dispose(); name.dispose(); phone.dispose(); nationalId.dispose(); job.dispose(); dept.dispose(); salary.dispose();
      return;
    }
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('إضافة موظف'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'كود الموظف *')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الموظف *')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
            TextField(
              controller: nationalId,
              keyboardType: TextInputType.number,
              maxLength: 14,
              decoration: InputDecoration(
                labelText: nationalIdRequired ? 'الرقم القومي *' : 'الرقم القومي (اختياري)',
                helperText: '14 رقمًا؛ يُحفظ في سجل الموارد البشرية المقيد بالصلاحيات.',
              ),
            ),
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
            final idValue = nationalId.text.trim();
            if (code.text.trim().isEmpty || name.text.trim().isEmpty || amount == null || amount < 0) {
              refresh(() => localError = 'راجع كود الموظف والاسم والراتب.');
              return;
            }
            if ((nationalIdRequired && idValue.isEmpty) ||
                (idValue.isNotEmpty && !RegExp(r'^[0-9]{14}$').hasMatch(idValue))) {
              refresh(() => localError = nationalIdRequired
                  ? 'الرقم القومي إلزامي ويجب أن يتكون من 14 رقمًا.'
                  : 'إذا أدخلت الرقم القومي فيجب أن يتكون من 14 رقمًا.');
              return;
            }
            Navigator.pop(ctx);
            setState(() { _saving = true; _error = null; });
            try {
              await _repo.addEmployee(companyId: _company.text, employeeCode: code.text,
                fullName: name.text, nationalId: nationalId.text, phone: phone.text, jobTitle: job.text,
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
    code.dispose(); name.dispose(); phone.dispose(); nationalId.dispose(); job.dispose(); dept.dispose(); salary.dispose();
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

  Future<void> _showLeaveDialog() async {
    if (_employees.isEmpty) {
      setState(() => _error = 'حمّل دليل الموظفين أولًا قبل إنشاء طلب إجازة.');
      return;
    }
    String? employeeId = _employees.isEmpty ? null : _s(_employees.first['id']);
    String leaveType = 'سنوية';
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    final reason = TextEditingController();
    String? localError;
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('طلب إجازة جديد'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: employeeId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الموظف'),
              items: _employees.map((e) => DropdownMenuItem<String>(
                value: _s(e['id']), child: Text(_employeeName(_s(e['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => refresh(() => employeeId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: leaveType,
              decoration: const InputDecoration(labelText: 'نوع الإجازة'),
              items: const [
                DropdownMenuItem(value: 'سنوية', child: Text('سنوية')),
                DropdownMenuItem(value: 'عارضة', child: Text('عارضة')),
                DropdownMenuItem(value: 'مرضية', child: Text('مرضية')),
                DropdownMenuItem(value: 'بدون أجر', child: Text('بدون أجر')),
              ],
              onChanged: (v) => refresh(() => leaveType = v ?? leaveType),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () async {
              final picked = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) refresh(() => start = picked);
            }, child: Text('من: ' + _dateOnly(start))),
            OutlinedButton(onPressed: () async {
              final picked = await showDatePicker(context: ctx, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) refresh(() => end = picked);
            }, child: Text('إلى: ' + _dateOnly(end))),
            TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'السبب / الملاحظات')),
            if (localError != null) Text(localError!, style: const TextStyle(color: Colors.red)),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (employeeId == null || start.isAfter(end)) {
              refresh(() => localError = 'اختر الموظف وتأكد من ترتيب التاريخين.');
              return;
            }
            Navigator.pop(ctx);
            setState(() { _saving = true; _error = null; _message = null; });
            try {
              await _repo.createLeaveRequest(companyId: _company.text, employeeId: employeeId!,
                leaveType: leaveType, start: start, end: end, reason: reason.text);
              if (!mounted) return;
              setState(() { _saving = false; _message = 'تم إنشاء طلب الإجازة بحالة انتظار الاعتماد.'; });
              await _load();
            } catch (e) {
              if (!mounted) return;
              setState(() { _saving = false; _error = 'تعذر إنشاء طلب الإجازة: $e'; });
            }
          }, child: const Text('حفظ الطلب')),
        ],
      )));
    reason.dispose();
  }

  Future<void> _decideLeave(Map<String, dynamic> request, String decision) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.decideLeave(_s(request['id']), decision);
      if (!mounted) return;
      setState(() { _saving = false; _message = decision == 'approved' ? 'تم اعتماد طلب الإجازة.' : 'تم رفض طلب الإجازة.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر اتخاذ القرار: $e'; });
    }
  }

  String _dateOnly(DateTime date) => date.year.toString().padLeft(4, '0') + '-' +
      date.month.toString().padLeft(2, '0') + '-' + date.day.toString().padLeft(2, '0');

  String _employeeName(String id) {
    final matches = _employees.where((e) => _s(e['id']) == id);
    return matches.isEmpty ? id : '${_s(matches.first['employee_code'])} — ${_s(matches.first['full_name'])}';
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewHrRecords(String title, List<Map<String, dynamic>> rows) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 760, child: rows.isEmpty ? const Text('لا توجد بيانات محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: rows.take(100).map((r) => ListTile(
          dense: true,
          title: Text('${r['full_name'] ?? r['employee_name'] ?? r['name'] ?? r['request_type'] ?? 'سجل'}'),
          subtitle: Text('${r['employee_code'] ?? r['status'] ?? r['attendance_date'] ?? ''}'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
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
        Card(color: const Color(0xFF3E007D), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('الموارد البشرية', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const Text('دليل الموظفين والحضور والانصراف والإجازات. صلاحيات الرواتب منفصلة.', style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('إضافة موظف', Icons.person_add_alt_1, const Color(0xFF168447), _saving ? null : _addEmployee),
              _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), () => _previewHrRecords(
                _view == 'employees' ? 'معاينة الموظفين' : _view == 'attendance' ? 'معاينة الحضور' : 'معاينة الإجازات',
                _view == 'employees' ? _employees : _view == 'attendance' ? _attendance : _leaveRequests)),
            ])),
          ]),
        )),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل البيانات')),
          OutlinedButton.icon(onPressed: _saving ? null : _addEmployee, icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة موظف')),
        ]),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        if (_loading || _saving) const LinearProgressIndicator(),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'employees', label: Text('الموظفون'), icon: Icon(Icons.badge_outlined)),
            ButtonSegment(value: 'attendance', label: Text('الحضور اليوم'), icon: Icon(Icons.access_time)),
            ButtonSegment(value: 'leave', label: Text('الإجازات'), icon: Icon(Icons.event_available)),
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
        ] else if (_view == 'attendance') ...[
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
        ] else ...[
          Row(children: [
            Expanded(child: Text('طلبات الإجازات • ' + _leaveRequests.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            FilledButton.icon(onPressed: _saving ? null : _showLeaveDialog, icon: const Icon(Icons.add), label: const Text('طلب جديد')),
          ]),
          if (_leaveRequests.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد طلبات إجازة مسجلة.')),
          ..._leaveRequests.map((request) {
            final status = _s(request['status']);
            return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_employeeName(_s(request['employee_id'])), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_s(request['leave_type']) + ' • ' + _s(request['starts_on']) + ' إلى ' + _s(request['ends_on']) +
                  ' • ' + _s(request['requested_days']) + ' يوم'),
                if (_s(request['reason']).isNotEmpty) Text('السبب: ' + _s(request['reason'])),
                Row(children: [
                  Chip(label: Text(status)),
                  const Spacer(),
                  if (status == 'pending') ...[
                    TextButton(onPressed: _saving ? null : () => _decideLeave(request, 'rejected'), child: const Text('رفض')),
                    const SizedBox(width: 6),
                    FilledButton(onPressed: _saving ? null : () => _decideLeave(request, 'approved'), child: const Text('اعتماد')),
                  ],
                ]),
              ],
            )));
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
).hasMatch(idValue))) {
              refresh(() => localError = nationalIdRequired
                  ? 'الرقم القومي إلزامي ويجب أن يتكون من 14 رقمًا.'
                  : 'إذا أدخلت الرقم القومي فيجب أن يتكون من 14 رقمًا.');
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

  Future<void> _showLeaveDialog() async {
    if (_employees.isEmpty) {
      setState(() => _error = 'حمّل دليل الموظفين أولًا قبل إنشاء طلب إجازة.');
      return;
    }
    String? employeeId = _employees.isEmpty ? null : _s(_employees.first['id']);
    String leaveType = 'سنوية';
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    final reason = TextEditingController();
    String? localError;
    await showDialog<void>(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('طلب إجازة جديد'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: employeeId, isExpanded: true,
              decoration: const InputDecoration(labelText: 'الموظف'),
              items: _employees.map((e) => DropdownMenuItem<String>(
                value: _s(e['id']), child: Text(_employeeName(_s(e['id'])), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => refresh(() => employeeId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: leaveType,
              decoration: const InputDecoration(labelText: 'نوع الإجازة'),
              items: const [
                DropdownMenuItem(value: 'سنوية', child: Text('سنوية')),
                DropdownMenuItem(value: 'عارضة', child: Text('عارضة')),
                DropdownMenuItem(value: 'مرضية', child: Text('مرضية')),
                DropdownMenuItem(value: 'بدون أجر', child: Text('بدون أجر')),
              ],
              onChanged: (v) => refresh(() => leaveType = v ?? leaveType),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () async {
              final picked = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) refresh(() => start = picked);
            }, child: Text('من: ' + _dateOnly(start))),
            OutlinedButton(onPressed: () async {
              final picked = await showDatePicker(context: ctx, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) refresh(() => end = picked);
            }, child: Text('إلى: ' + _dateOnly(end))),
            TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'السبب / الملاحظات')),
            if (localError != null) Text(localError!, style: const TextStyle(color: Colors.red)),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (employeeId == null || start.isAfter(end)) {
              refresh(() => localError = 'اختر الموظف وتأكد من ترتيب التاريخين.');
              return;
            }
            Navigator.pop(ctx);
            setState(() { _saving = true; _error = null; _message = null; });
            try {
              await _repo.createLeaveRequest(companyId: _company.text, employeeId: employeeId!,
                leaveType: leaveType, start: start, end: end, reason: reason.text);
              if (!mounted) return;
              setState(() { _saving = false; _message = 'تم إنشاء طلب الإجازة بحالة انتظار الاعتماد.'; });
              await _load();
            } catch (e) {
              if (!mounted) return;
              setState(() { _saving = false; _error = 'تعذر إنشاء طلب الإجازة: $e'; });
            }
          }, child: const Text('حفظ الطلب')),
        ],
      )));
    reason.dispose();
  }

  Future<void> _decideLeave(Map<String, dynamic> request, String decision) async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.decideLeave(_s(request['id']), decision);
      if (!mounted) return;
      setState(() { _saving = false; _message = decision == 'approved' ? 'تم اعتماد طلب الإجازة.' : 'تم رفض طلب الإجازة.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر اتخاذ القرار: $e'; });
    }
  }

  String _dateOnly(DateTime date) => date.year.toString().padLeft(4, '0') + '-' +
      date.month.toString().padLeft(2, '0') + '-' + date.day.toString().padLeft(2, '0');

  String _employeeName(String id) {
    final matches = _employees.where((e) => _s(e['id']) == id);
    return matches.isEmpty ? id : '${_s(matches.first['employee_code'])} — ${_s(matches.first['full_name'])}';
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewHrRecords(String title, List<Map<String, dynamic>> rows) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 760, child: rows.isEmpty ? const Text('لا توجد بيانات محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: rows.take(100).map((r) => ListTile(
          dense: true,
          title: Text('${r['full_name'] ?? r['employee_name'] ?? r['name'] ?? r['request_type'] ?? 'سجل'}'),
          subtitle: Text('${r['employee_code'] ?? r['status'] ?? r['attendance_date'] ?? ''}'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
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
        Card(color: const Color(0xFF3E007D), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('الموارد البشرية', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const Text('دليل الموظفين والحضور والانصراف والإجازات. صلاحيات الرواتب منفصلة.', style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _quickTask('إضافة موظف', Icons.person_add_alt_1, const Color(0xFF168447), _saving ? null : _addEmployee),
              _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), () => _previewHrRecords(
                _view == 'employees' ? 'معاينة الموظفين' : _view == 'attendance' ? 'معاينة الحضور' : 'معاينة الإجازات',
                _view == 'employees' ? _employees : _view == 'attendance' ? _attendance : _leaveRequests)),
            ])),
          ]),
        )),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل البيانات')),
          OutlinedButton.icon(onPressed: _saving ? null : _addEmployee, icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة موظف')),
        ]),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        if (_loading || _saving) const LinearProgressIndicator(),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'employees', label: Text('الموظفون'), icon: Icon(Icons.badge_outlined)),
            ButtonSegment(value: 'attendance', label: Text('الحضور اليوم'), icon: Icon(Icons.access_time)),
            ButtonSegment(value: 'leave', label: Text('الإجازات'), icon: Icon(Icons.event_available)),
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
        ] else if (_view == 'attendance') ...[
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
        ] else ...[
          Row(children: [
            Expanded(child: Text('طلبات الإجازات • ' + _leaveRequests.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            FilledButton.icon(onPressed: _saving ? null : _showLeaveDialog, icon: const Icon(Icons.add), label: const Text('طلب جديد')),
          ]),
          if (_leaveRequests.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد طلبات إجازة مسجلة.')),
          ..._leaveRequests.map((request) {
            final status = _s(request['status']);
            return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_employeeName(_s(request['employee_id'])), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_s(request['leave_type']) + ' • ' + _s(request['starts_on']) + ' إلى ' + _s(request['ends_on']) +
                  ' • ' + _s(request['requested_days']) + ' يوم'),
                if (_s(request['reason']).isNotEmpty) Text('السبب: ' + _s(request['reason'])),
                Row(children: [
                  Chip(label: Text(status)),
                  const Spacer(),
                  if (status == 'pending') ...[
                    TextButton(onPressed: _saving ? null : () => _decideLeave(request, 'rejected'), child: const Text('رفض')),
                    const SizedBox(width: 6),
                    FilledButton(onPressed: _saving ? null : () => _decideLeave(request, 'approved'), child: const Text('اعتماد')),
                  ],
                ]),
              ],
            )));
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
