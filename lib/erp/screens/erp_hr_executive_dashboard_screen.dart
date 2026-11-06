import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hrPurple = Color(0xFF3E007D);
const _hrOrange = Color(0xFFFFA015);
const _hrPink = Color(0xFFFF27C3);
const _hrBg = Color(0xFFFAF8FC);

class ErpHrExecutiveDashboardScreen extends StatefulWidget {
  const ErpHrExecutiveDashboardScreen({super.key, this.companyId, this.canManage = false});
  final String? companyId;
  final bool canManage;

  @override
  State<ErpHrExecutiveDashboardScreen> createState() => _ErpHrExecutiveDashboardScreenState();
}

class _ErpHrExecutiveDashboardScreenState extends State<ErpHrExecutiveDashboardScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  int _analysisPeriodDays = 365;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _payrollRuns = [];
  List<Map<String, dynamic>> _compliance = [];
  List<Map<String, dynamic>> _training = [];
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _leaves = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) {
      setState(() { _loading = false; _error = 'افتح بيانات الشركة أولاً حتى تظهر مؤشرات الموارد البشرية الخاصة بها.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      final dateStart = '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}-01';
      final dateEnd = '${monthEnd.year.toString().padLeft(4, '0')}-${monthEnd.month.toString().padLeft(2, '0')}-${monthEnd.day.toString().padLeft(2, '0')}';
      final results = await Future.wait([
        _db.from('erp_employees').select('id,employee_code,full_name,department_name,job_title,is_active,employment_status,work_unit,job_id,hire_date,contract_type,contract_start_date,contract_end_date,notes').eq('company_id', companyId).limit(3000),
        _db.from('erp_hr_departments').select('id,department_code,name_ar,department_level,parent_id,is_active').eq('company_id', companyId).limit(1000),
        _db.from('erp_hr_jobs').select('id,job_code,name_ar,department_id,is_active,requires_photo,requires_birth_certificate,requires_qualification_certificate,requires_work_card,requires_insurance_printout,requires_military_service,requires_criminal_record,requires_trust_receipt,requires_health_certificate,requires_driving_license,requires_id_copy,requires_bank_account').eq('company_id', companyId).limit(1000),
        _db.from('erp_employee_documents').select('employee_id,doc_type').eq('company_id', companyId).limit(10000),
        _db.from('erp_attendance_records').select('employee_id,work_date,attendance_status,late_minutes,overtime_minutes').eq('company_id', companyId).gte('work_date', dateStart).lte('work_date', dateEnd).limit(10000),
        _db.from('erp_payroll_runs').select('id,run_code,period_start,period_end,status,employee_count,gross_total,net_total').eq('company_id', companyId).order('period_start', ascending: false).limit(12),
        _db.from('erp_hr_employee_compliance').select('id,employee_id,record_type,status,expires_on,created_at').eq('company_id', companyId).order('created_at', ascending: false).limit(2000),
        _db.from('erp_hr_training_records').select('id,employee_id,course_name,status,certificate_expires_on,ends_on').eq('company_id', companyId).order('created_at', ascending: false).limit(2000),
        _db.from('erp_hr_recruitment_candidates').select('id,candidate_name,status,applied_on,decision_on,job_id').eq('company_id', companyId).order('applied_on', ascending: false).limit(2000),
        _db.from('erp_hr_employee_movements').select('id,employee_id,movement_type,effective_on,reason').eq('company_id', companyId).order('effective_on', ascending: false).limit(5000),
        _db.from('erp_leave_requests').select('id,employee_id,status,starts_on,ends_on,requested_days').eq('company_id', companyId).gte('starts_on', dateStart).lte('starts_on', dateEnd).limit(5000),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = List<Map<String, dynamic>>.from(results[0]);
        _departments = List<Map<String, dynamic>>.from(results[1]);
        _jobs = List<Map<String, dynamic>>.from(results[2]);
        _documents = List<Map<String, dynamic>>.from(results[3]);
        _attendance = List<Map<String, dynamic>>.from(results[4]);
        _payrollRuns = List<Map<String, dynamic>>.from(results[5]);
        _compliance = List<Map<String, dynamic>>.from(results[6]);
        _training = List<Map<String, dynamic>>.from(results[7]);
        _candidates = List<Map<String, dynamic>>.from(results[8]);
        _movements = List<Map<String, dynamic>>.from(results[9]);
        _leaves = List<Map<String, dynamic>>.from(results[10]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل مؤشرات الموارد البشرية: $e'; });
    }
  }

  bool _isTemporarySeedEmployee(Map<String, dynamic> employee) =>
      (employee['notes']?.toString() ?? '').contains('بيانات أولية مؤقتة');
  List<Map<String, dynamic>> get _realEmployees =>
      _employees.where((employee) => !_isTemporarySeedEmployee(employee)).toList();
  bool _isCurrentEmployee(Map<String, dynamic> employee) {
    if (employee['is_active'] != true || _isTemporarySeedEmployee(employee)) return false;
    final hireDate = _asDate(employee['hire_date']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return hireDate == null || !hireDate.isAfter(today);
  }
  int get _temporaryEmployees => _employees.where(_isTemporarySeedEmployee).length;
  int get _upcomingHires => _realEmployees.where((employee) {
    final hireDate = _asDate(employee['hire_date']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return employee['is_active'] == true && hireDate != null && hireDate.isAfter(today);
  }).length;
  int get _activeEmployees => _realEmployees.where(_isCurrentEmployee).length;
  int get _inactiveEmployees => _realEmployees.where((e) => e['is_active'] != true).length;
  int get _activeDepartments => _departments.where((e) => e['is_active'] != false).length;
  int get _activeJobs => _jobs.where((e) => e['is_active'] != false).length;
  int get _unassignedJobs => _jobs.where((j) => j['department_id'] == null).length;
  int get _departmentsWithoutJobs => _departments.where((d) =>
      !_jobs.any((j) => j['department_id']?.toString() == d['id']?.toString())).length;
  int get _employeesWithoutJob => _realEmployees.where((e) => _isCurrentEmployee(e) && e['job_id'] == null).length;
  int get _employeesWithoutContract => _realEmployees.where((e) => _isCurrentEmployee(e) && (e['contract_type'] == null || e['contract_type'].toString().trim().isEmpty || e['contract_type'] == 'بدون عقد')).length;
  List<MapEntry<String, int>> get _employeesByDepartment {
    final counts = <String, int>{};
    for (final employee in _realEmployees.where(_isCurrentEmployee)) {
      final department = (employee['department_name'] ?? 'إدارة غير محددة').toString();
      counts[department] = (counts[department] ?? 0) + 1;
    }
    final rows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  DateTime? _asDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  int get _contractsExpiringSoon => _realEmployees.where((e) {
    final end = _asDate(e['contract_end_date']);
    if (end == null || !_isCurrentEmployee(e) || e['contract_type'] != 'بعقد') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = end.difference(today).inDays;
    return days >= 0 && days <= 30;
  }).length;

  int get _contractsExpired => _realEmployees.where((e) {
    final end = _asDate(e['contract_end_date']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return end != null && end.isBefore(today) && _isCurrentEmployee(e) && e['contract_type'] == 'بعقد';
  }).length;

  int get _contractsWithoutEndDate => _realEmployees.where((e) =>
      _isCurrentEmployee(e) && e['contract_type'] == 'بعقد' &&
      (_asDate(e['contract_start_date']) == null || _asDate(e['contract_end_date']) == null)).length;

  Map<String, dynamic>? _jobForEmployee(Map<String, dynamic> employee) {
    for (final job in _jobs) {
      if (job['id']?.toString() == employee['job_id']?.toString()) return job;
    }
    return null;
  }

  int get _employeesMissingRequiredDocuments => _realEmployees.where((employee) {
    final job = _jobForEmployee(employee);
    if (job == null) return false;
    final required = <String, String>{
      'requires_photo': 'personal_id',
      'requires_birth_certificate': 'birth_certificate',
      'requires_qualification_certificate': 'qualification',
      'requires_work_card': 'labor_card',
      'requires_insurance_printout': 'insurance_print',
      'requires_military_service': 'military_status',
      'requires_criminal_record': 'criminal_record',
      'requires_trust_receipt': 'trust_receipt',
      'requires_health_certificate': 'health_certificate',
      'requires_driving_license': 'driving_license',
      'requires_id_copy': 'personal_id',
      'requires_bank_account': 'bank_account',
    };
    final present = _documents.where((d) => d['employee_id']?.toString() == employee['id']?.toString()).map((d) => d['doc_type']?.toString()).toSet();
    return required.entries.any((entry) => job[entry.key] == true && !present.contains(entry.value));
  }).length;

  int get _lateAttendanceCount => _attendance.where((r) => (r['late_minutes'] as num? ?? 0) > 0).length;
  int get _absenceAttendanceCount => _attendance.where((r) => (r['attendance_status']?.toString().toLowerCase() ?? '').contains('absent') || (r['attendance_status']?.toString() ?? '').contains('غائب') || (r['attendance_status']?.toString() ?? '').contains('غياب')).length;
  int get _overtimeMinutes => _attendance.fold<int>(0, (sum, r) => sum + ((r['overtime_minutes'] as num?)?.toInt() ?? 0));
  int get _pendingPayrollRuns => _payrollRuns.where((r) => !const ['approved', 'posted', 'paid'].contains(r['status']?.toString().toLowerCase())).length;
  num _numberValue(dynamic value) => value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
  Map<String, dynamic>? get _latestPayrollRun => _payrollRuns.isEmpty ? null : _payrollRuns.first;
  String _moneyLabel(dynamic value) {
    final amount = _numberValue(value);
    return '${amount.toStringAsFixed(2)} ج.م';
  }
  Map<String, String> _latestComplianceStatusByEmployee(String type) {
    final latest = <String, String>{};
    final activeIds = _realEmployees.where(_isCurrentEmployee).map((e) => e['id']?.toString()).whereType<String>().toSet();
    // Compliance rows are loaded newest-first; keep one effective status per employee and record type.
    for (final row in _compliance) {
      if (row['record_type'] != type || row['employee_id'] == null || !activeIds.contains(row['employee_id'].toString())) continue;
      latest.putIfAbsent(row['employee_id'].toString(), () => row['status']?.toString() ?? '');
    }
    return latest;
  }
  int _distinctComplianceEmployees(String type, String status) =>
      _latestComplianceStatusByEmployee(type).values.where((value) => value == status).length;
  int _distinctComplianceStatus(String type, Set<String> statuses) =>
      _latestComplianceStatusByEmployee(type).values.where(statuses.contains).length;
  int get _healthInsured => _distinctComplianceEmployees('health_insurance', 'insured');
  int get _healthUninsured => _distinctComplianceEmployees('health_insurance', 'uninsured');
  int get _socialInsured => _distinctComplianceEmployees('social_insurance', 'insured');
  int get _socialUninsured => _distinctComplianceEmployees('social_insurance', 'uninsured');
  int get _healthInProgress => _distinctComplianceStatus('health_insurance', {'in_progress'});
  int get _socialInProgress => _distinctComplianceStatus('social_insurance', {'in_progress'});
  int get _insuranceInProgress => _healthInProgress + _socialInProgress;
  int get _healthNotRecorded => (_activeEmployees - _distinctComplianceStatus('health_insurance', {'insured','uninsured','in_progress','not_required'})).clamp(0, _activeEmployees).toInt();
  int get _socialNotRecorded => (_activeEmployees - _distinctComplianceStatus('social_insurance', {'insured','uninsured','in_progress','not_required'})).clamp(0, _activeEmployees).toInt();
  int get _contractsActive => _realEmployees.where((e) {
    final type = e['contract_type']?.toString() ?? '';
    if (!_isCurrentEmployee(e) || type.isEmpty || type == 'بدون عقد') return false;
    if (type != 'بعقد') return true;
    final start = _asDate(e['contract_start_date']);
    final end = _asDate(e['contract_end_date']);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return start != null && end != null && !start.isAfter(today) && !end.isBefore(today);
  }).length;
  int get _contractsMissing => _realEmployees.where((e) =>
      _isCurrentEmployee(e) &&
      ((e['contract_type'] == null || e['contract_type'].toString().trim().isEmpty || e['contract_type'] == 'بدون عقد') ||
       (e['contract_type'] == 'بعقد' && (_asDate(e['contract_start_date']) == null || _asDate(e['contract_end_date']) == null)))).length;
  int get _licensesExpired => _compliance.where((r) => r['record_type'] == 'license' && (r['status'] == 'expired' || (_asDate(r['expires_on'])?.isBefore(DateTime.now()) ?? false))).length;
  int get _licensesExpiringSoon => _compliance.where((r) { final d = _asDate(r['expires_on']); if (r['record_type'] != 'license' || d == null) return false; final n = DateTime.now(); final t = DateTime(n.year,n.month,n.day); final days = d.difference(t).inDays; return days >= 0 && days <= 30; }).length;
  int get _trainingPlanned => _training.where((r) => r['status'] == 'planned').length;
  int get _trainingInProgress => _training.where((r) => r['status'] == 'in_progress').length;
  int get _trainingCompleted => _training.where((r) => r['status'] == 'completed').length;
  int get _trainingExpired => _training.where((r) => r['status'] == 'expired').length;
  int get _trainingCertificatesExpiring => _training.where((r) { final d = _asDate(r['certificate_expires_on']); if (d == null) return false; final n=DateTime.now(); final t=DateTime(n.year,n.month,n.day); final days=d.difference(t).inDays; return days>=0 && days<=30; }).length;
  int get _trainingCertificatesExpired => _training.where((r) { final d = _asDate(r['certificate_expires_on']); if (d == null) return false; final n=DateTime.now(); final t=DateTime(n.year,n.month,n.day); return d.isBefore(t); }).length;
  int _candidateCount(String status) => _candidates.where((r) => r['status'] == status).length;
  int get _candidateOpen => _candidates.where((r) => !const ['accepted','rejected','withdrawn'].contains(r['status'])).length;
  int get _candidateInterviews => _candidateCount('interview');
  int get _candidateScreening => _candidateCount('screening');
  int get _candidateDecided => _candidateCount('accepted') + _candidateCount('rejected');
  double get _candidateAcceptanceRate => _candidateDecided == 0 ? 0 : _candidateCount('accepted') / _candidateDecided * 100;
  DateTime get _analysisCutoff {
    final date = DateTime.now().subtract(Duration(days: _analysisPeriodDays));
    return DateTime(date.year, date.month, date.day);
  }
  int get _separationsInPeriod => _movements.where((r) => const ['resignation','termination','retirement'].contains(r['movement_type']) && (_asDate(r['effective_on'])?.isAfter(_analysisCutoff) ?? false)).length;
  int get _resignationsInPeriod => _movements.where((r) => r['movement_type'] == 'resignation' && (_asDate(r['effective_on'])?.isAfter(_analysisCutoff) ?? false)).length;
  int get _hiresInPeriod => _realEmployees.where((r) { final date = _asDate(r['hire_date']); final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); return date != null && date.isAfter(_analysisCutoff) && !date.isAfter(today); }).length;
  int get _separationsLast12Months => _movements.where((r) => const ['resignation','termination','retirement'].contains(r['movement_type']) && (_asDate(r['effective_on'])?.isAfter(DateTime.now().subtract(const Duration(days:365))) ?? false)).length;
  double get _turnoverRate {
    final current = _activeEmployees;
    final start = current + _separationsInPeriod - _hiresInPeriod;
    final average = (start + current) / 2;
    return average <= 0 ? 0 : (_separationsInPeriod / average) * 100;
  }
  // Avoid reporting a false zero turnover rate before service-movement history is recorded.
  String get _turnoverRateDisplay => _movements.where((r) => _asDate(r['effective_on'])?.isAfter(_analysisCutoff) ?? false).isEmpty
      ? 'غير متاح — لا توجد حركات خدمة مسجلة في الفترة'
      : '${_turnoverRate.toStringAsFixed(1)}%';
  int get _pendingLeaveRequests => _leaves.where((r) => !const ['approved','rejected','مقبول','مرفوض'].contains(r['status']?.toString().toLowerCase())).length;
  List<MapEntry<String, int>> get _separationsByDepartment {
    final counts = <String, int>{};
    final cutoff = _analysisCutoff;
    for (final movement in _movements) {
      if (!const ['resignation','termination','retirement'].contains(movement['movement_type'])) continue;
      final movedOn = _asDate(movement['effective_on']);
      if (movedOn == null || movedOn.isBefore(cutoff)) continue;
      Map<String, dynamic>? employee;
      for (final row in _employees) {
        if (row['id']?.toString() == movement['employee_id']?.toString()) { employee = row; break; }
      }
      final department = (employee?['department_name'] ?? 'إدارة غير محددة').toString();
      counts[department] = (counts[department] ?? 0) + 1;
    }
    final rows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }


  String _displayDate(DateTime date) =>
      date.day.toString().padLeft(2, '0') + '-' +
      date.month.toString().padLeft(2, '0') + '-' +
      date.year.toString().padLeft(4, '0');

  String? _dateValue(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    DateTime? parsed;
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(v)) {
      final parts = v.split('-');
      parsed = DateTime.tryParse(parts[2] + '-' + parts[1] + '-' + parts[0]);
      if (parsed != null && _displayDate(parsed) != v) parsed = null;
    } else {
      parsed = DateTime.tryParse(v);
    }
    if (parsed == null) throw FormatException('اكتب التاريخ بصيغة DD-MM-YYYY');
    return parsed.year.toString().padLeft(4, '0') + '-' +
        parsed.month.toString().padLeft(2, '0') + '-' +
        parsed.day.toString().padLeft(2, '0');
  }

  Widget _employeePicker(String? selected, ValueChanged<String?> onChanged) {
    final items = _employees.map((e) => DropdownMenuItem<String>(
      value: e['id'].toString(),
      child: Text('${e['employee_code'] ?? ''} • ${e['full_name'] ?? ''}', overflow: TextOverflow.ellipsis),
    )).toList();
    return DropdownButtonFormField<String>(
      value: _employees.any((e) => e['id']?.toString() == selected) ? selected : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'الموظف *'),
      items: items,
      onChanged: onChanged,
    );
  }

  Future<void> _insertHrRecord(String table, Map<String, dynamic> values) async {
    final companyId = widget.companyId;
    if (companyId == null || companyId.isEmpty) throw StateError('معرّف الشركة غير متاح.');
    await _db.from(table).insert({
      ...values,
      'company_id': companyId,
      'created_by': _db.auth.currentUser?.id,
    });
    if (mounted) await _load();
  }

  Future<void> _addCompliance() async {
    if (_employees.isEmpty) { _showMessage('أضف الموظفين أولًا حتى يمكن ربط سجل التأمين أو الرخصة.'); return; }
    final provider = TextEditingController(), reference = TextEditingController(), issued = TextEditingController(), expires = TextEditingController(), notes = TextEditingController();
    String? employeeId = _employees.first['id']?.toString();
    String type = 'health_insurance', status = 'in_progress';
    try {
      await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('إضافة سجل تأمين أو رخصة'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _employeePicker(employeeId, (v) => refresh(() => employeeId = v)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'نوع السجل'), items: const [
            DropdownMenuItem(value: 'health_insurance', child: Text('تأمين صحي')),
            DropdownMenuItem(value: 'social_insurance', child: Text('تأمين اجتماعي')),
            DropdownMenuItem(value: 'license', child: Text('رخصة')),
          ], onChanged: (v) => refresh(() { type = v ?? type; status = type == 'license' ? 'valid' : 'in_progress'; })),
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'الحالة'), items: const [
            DropdownMenuItem(value: 'insured', child: Text('مؤمن')),
            DropdownMenuItem(value: 'uninsured', child: Text('غير مؤمن')),
            DropdownMenuItem(value: 'in_progress', child: Text('جارٍ')),
            DropdownMenuItem(value: 'valid', child: Text('سارية')),
            DropdownMenuItem(value: 'expired', child: Text('منتهية')),
            DropdownMenuItem(value: 'not_required', child: Text('غير مطلوب')),
          ], onChanged: (v) => refresh(() => status = v ?? status)),
          TextField(controller: provider, decoration: const InputDecoration(labelText: 'الجهة / شركة التأمين')),
          TextField(controller: reference, decoration: const InputDecoration(labelText: 'رقم الوثيقة / الرخصة')),
          TextField(controller: issued, decoration: const InputDecoration(labelText: 'تاريخ الإصدار DD-MM-YYYY')),
          TextField(controller: expires, decoration: const InputDecoration(labelText: 'تاريخ الانتهاء DD-MM-YYYY')),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (employeeId == null) { _showMessage('اختر الموظف.'); return; }
            try {
              await _insertHrRecord('erp_hr_employee_compliance', {
                'employee_id': employeeId, 'record_type': type, 'status': status,
                'provider': provider.text.trim(), 'reference_number': reference.text.trim(),
                'issued_on': _dateValue(issued.text), 'expires_on': _dateValue(expires.text), 'notes': notes.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) { _showMessage('تعذر حفظ السجل: $e'); }
          }, child: const Text('حفظ')),
        ],
      )));
    } finally { provider.dispose(); reference.dispose(); issued.dispose(); expires.dispose(); notes.dispose(); }
  }

  Future<void> _addTraining() async {
    if (_employees.isEmpty) { _showMessage('أضف الموظفين أولًا حتى يمكن ربط التدريب بهم.'); return; }
    final course = TextEditingController(), provider = TextEditingController(), starts = TextEditingController(), ends = TextEditingController(), expiry = TextEditingController(), notes = TextEditingController();
    String? employeeId = _employees.first['id']?.toString();
    String status = 'planned';
    try {
      await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('تسجيل برنامج تدريبي'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _employeePicker(employeeId, (v) => refresh(() => employeeId = v)),
          TextField(controller: course, decoration: const InputDecoration(labelText: 'اسم البرنامج التدريبي *')),
          TextField(controller: provider, decoration: const InputDecoration(labelText: 'جهة التدريب')),
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'الحالة'), items: const [
            DropdownMenuItem(value: 'planned', child: Text('مخطط')),
            DropdownMenuItem(value: 'in_progress', child: Text('جارٍ')),
            DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
            DropdownMenuItem(value: 'expired', child: Text('منتهي')),
            DropdownMenuItem(value: 'cancelled', child: Text('ملغي')),
          ], onChanged: (v) => refresh(() => status = v ?? status)),
          TextField(controller: starts, decoration: const InputDecoration(labelText: 'تاريخ البداية DD-MM-YYYY')),
          TextField(controller: ends, decoration: const InputDecoration(labelText: 'تاريخ النهاية DD-MM-YYYY')),
          TextField(controller: expiry, decoration: const InputDecoration(labelText: 'انتهاء الشهادة DD-MM-YYYY')),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (employeeId == null || course.text.trim().isEmpty) { _showMessage('اختر الموظف واكتب اسم البرنامج.'); return; }
            try {
              await _insertHrRecord('erp_hr_training_records', {
                'employee_id': employeeId, 'course_name': course.text.trim(), 'provider': provider.text.trim(),
                'status': status, 'starts_on': _dateValue(starts.text), 'ends_on': _dateValue(ends.text),
                'certificate_expires_on': _dateValue(expiry.text), 'notes': notes.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) { _showMessage('تعذر حفظ التدريب: $e'); }
          }, child: const Text('حفظ')),
        ],
      )));
    } finally { course.dispose(); provider.dispose(); starts.dispose(); ends.dispose(); expiry.dispose(); notes.dispose(); }
  }

  Future<void> _addCandidate() async {
    final name = TextEditingController(), phone = TextEditingController(), email = TextEditingController(), source = TextEditingController(), notes = TextEditingController();
    String status = 'new';
    String? jobId;
    try {
      await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('إضافة متقدم لوظيفة'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المتقدم *')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
          DropdownButtonFormField<String>(value: jobId, decoration: const InputDecoration(labelText: 'الوظيفة المطلوبة (اختياري)'), items: [
            const DropdownMenuItem<String>(value: null, child: Text('غير محددة')),
            ..._jobs.map((j) => DropdownMenuItem<String>(value: j['id'].toString(), child: Text(j['name_ar']?.toString() ?? 'وظيفة'))),
          ], onChanged: (v) => refresh(() => jobId = v)),
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'حالة الطلب'), items: const [
            DropdownMenuItem(value: 'new', child: Text('جديد')),
            DropdownMenuItem(value: 'screening', child: Text('فرز')),
            DropdownMenuItem(value: 'interview', child: Text('مقابلة')),
            DropdownMenuItem(value: 'accepted', child: Text('مقبول')),
            DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
            DropdownMenuItem(value: 'withdrawn', child: Text('منسحب')),
          ], onChanged: (v) => refresh(() => status = v ?? status)),
          TextField(controller: source, decoration: const InputDecoration(labelText: 'مصدر المتقدم')),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) { _showMessage('اكتب اسم المتقدم.'); return; }
            try {
              await _insertHrRecord('erp_hr_recruitment_candidates', {
                'candidate_name': name.text.trim(), 'phone': phone.text.trim(), 'email': email.text.trim(),
                'job_id': jobId, 'status': status, 'source': source.text.trim(), 'notes': notes.text.trim(),
                'decision_on': const ['accepted','rejected','withdrawn'].contains(status) ? DateTime.now().toIso8601String().substring(0,10) : null,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) { _showMessage('تعذر حفظ المتقدم: $e'); }
          }, child: const Text('حفظ')),
        ],
      )));
    } finally { name.dispose(); phone.dispose(); email.dispose(); source.dispose(); notes.dispose(); }
  }

  Future<void> _addMovement() async {
    if (_employees.isEmpty) { _showMessage('لا يوجد موظفون لربط الحركة بهم.'); return; }
    final reason = TextEditingController(), notes = TextEditingController(), effective = TextEditingController(text: _displayDate(DateTime.now()));
    String? employeeId = _employees.first['id']?.toString();
    String type = 'resignation';
    try {
      await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        title: const Text('تسجيل حركة موظف'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _employeePicker(employeeId, (v) => refresh(() => employeeId = v)),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'نوع الحركة'), items: const [
            DropdownMenuItem(value: 'resignation', child: Text('استقالة')),
            DropdownMenuItem(value: 'termination', child: Text('إنهاء خدمة')),
            DropdownMenuItem(value: 'retirement', child: Text('تقاعد')),
            DropdownMenuItem(value: 'transfer', child: Text('نقل')),
            DropdownMenuItem(value: 'suspension', child: Text('إيقاف مؤقت')),
            DropdownMenuItem(value: 'return_to_work', child: Text('عودة للعمل')),
            DropdownMenuItem(value: 'hire', child: Text('تعيين')),
          ], onChanged: (v) => refresh(() => type = v ?? type)),
          TextField(controller: effective, decoration: const InputDecoration(labelText: 'تاريخ سريان الحركة DD-MM-YYYY')),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب الحركة')),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            if (employeeId == null) { _showMessage('اختر الموظف.'); return; }
            try {
              await _insertHrRecord('erp_hr_employee_movements', {
                'employee_id': employeeId, 'movement_type': type, 'effective_on': _dateValue(effective.text) ?? DateTime.now().toIso8601String().substring(0,10),
                'reason': reason.text.trim(), 'notes': notes.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) { _showMessage('تعذر حفظ الحركة: $e'); }
          }, child: const Text('حفظ')),
        ],
      )));
    } finally { reason.dispose(); notes.dispose(); effective.dispose(); }
  }


  String _employeeLabel(dynamic id) {
    for (final employee in _employees) {
      if (employee['id']?.toString() == id?.toString()) {
        return '${employee['employee_code'] ?? ''} • ${employee['full_name'] ?? ''}';
      }
    }
    return 'موظف غير محدد';
  }

  String _hrStatusLabel(String status) => const {
    'new':'جديد','screening':'فرز','interview':'مقابلة','accepted':'مقبول',
    'rejected':'مرفوض','withdrawn':'منسحب','insured':'مؤمن','uninsured':'غير مؤمن',
    'in_progress':'جارٍ','valid':'سارية','expired':'منتهية','not_required':'غير مطلوب',
    'planned':'مخطط','completed':'مكتمل','cancelled':'ملغي',
  }[status] ?? status;

  Future<void> _changeHrRecordStatus({
    required String table,
    required String id,
    required String current,
    required List<MapEntry<String, String>> options,
    bool recruitment = false,
  }) async {
    String selected = current;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('تحديث حالة السجل'),
      content: DropdownButtonFormField<String>(
        value: selected,
        decoration: const InputDecoration(labelText: 'الحالة الجديدة'),
        items: options.map((o) => DropdownMenuItem<String>(value: o.key, child: Text(o.value))).toList(),
        onChanged: (v) => refresh(() => selected = v ?? selected),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          try {
            final values = <String, dynamic>{'status': selected, 'updated_at': DateTime.now().toIso8601String()};
            if (recruitment) {
              values['decision_on'] = const ['accepted','rejected','withdrawn'].contains(selected)
                  ? DateTime.now().toIso8601String().substring(0, 10) : null;
            }
            await _db.from(table).update(values).eq('id', id).eq('company_id', widget.companyId!);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) await _load();
          } catch (e) { _showMessage('تعذر تحديث الحالة: $e'); }
        }, child: const Text('حفظ')),
      ],
    )));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      color: _hrBg,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ملخص إدارة الموارد البشرية', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _hrPurple)),
            SizedBox(height: 4),
            Text('لوحة القيادة التنفيذية لرأس المال البشري • سلسلة', style: TextStyle(color: Colors.black54)),
          ])),
          IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث المؤشرات', icon: const Icon(Icons.refresh, color: _hrPurple)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_hrPurple, Color(0xFF6420A0)], begin: Alignment.centerRight, end: Alignment.centerLeft),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.insights_rounded, color: _hrOrange, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('لوحة قيادة رأس المال البشري', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              SizedBox(height: 3),
              Text('مؤشرات القوى العاملة والامتثال والكفاءة والتوظيف', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
              child: const Text('SILSILA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        if (_error != null) _notice(_error!, Icons.info_outline, Colors.orange.shade800),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: _hrPurple)))
        else Expanded(child: ListView(children: [
          _panel(children: [
            Row(children: [
              const Expanded(child: Text('فترة التحليل', style: TextStyle(fontWeight: FontWeight.w900, color: _hrPurple))),
              SizedBox(width: 180, child: DropdownButtonFormField<int>(
                value: _analysisPeriodDays,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('آخر 30 يومًا', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 90, child: Text('آخر 90 يومًا', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 180, child: Text('آخر 6 أشهر', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 365, child: Text('آخر 12 شهرًا', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _analysisPeriodDays = value ?? 365),
              )),
            ]),
            const SizedBox(height: 8),
            Text('تُطبق الفترة على التعيينات وحركات انتهاء الخدمة ومعدل دوران العمالة.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
          const SizedBox(height: 12),
          _sectionTitle('مؤشرات القوى العاملة', Icons.groups_2_outlined),
          LayoutBuilder(builder: (context, c) {
            final count = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
            return GridView.count(
              crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: count == 1 ? 3.3 : 2.25,
              children: [
                _metric('إجمالي الموظفين', _realEmployees.length.toString(), 'بعد استبعاد السجلات المؤقتة', Icons.badge_outlined, _hrPurple),
                _metric('موظفون نشطون', _activeEmployees.toString(), 'على رأس العمل حسب حالة الملف', Icons.verified_user_outlined, Colors.green.shade700),
                _metric('غير نشطين', _inactiveEmployees.toString(), 'ملفات غير محددة كنشطة', Icons.person_off_outlined, Colors.red.shade700),
                _metric('الإدارات النشطة', _activeDepartments.toString(), 'من الهيكل التنظيمي', Icons.account_tree_outlined, _hrOrange),
                _metric('الوظائف النشطة', _activeJobs.toString(), 'وظائف معرفة بالهيكل', Icons.work_outline, _hrPink),
              ],
            );
          }),
          const SizedBox(height: 18),
          _sectionTitle('الهيكل التنظيمي والوظائف', Icons.corporate_fare_outlined),
          _panel(children: [
            _progressRow('الوظائف النشطة', _activeJobs, _jobs.length, _hrPurple),
            _progressRow('إدارات بلا وظائف مرتبطة', _departmentsWithoutJobs, _departments.length, _hrOrange),
            _progressRow('وظائف غير مرتبطة بإدارة', _unassignedJobs, _jobs.length, _hrPink),
            _progressRow('موظفون بلا وظيفة محددة', _employeesWithoutJob, _realEmployees.length, _hrPink),
            _progressRow('اكتمال ربط الموظفين بوظائف', (_realEmployees.length - _employeesWithoutJob).clamp(0, _realEmployees.length).toInt(), _realEmployees.length, _hrPurple),
            if (_departments.isEmpty || _jobs.isEmpty)
              _notice('استكمل تعريف الإدارات والوظائف وربط كل وظيفة بإدارتها حتى تصبح مؤشرات اكتمال الهيكل دقيقة.', Icons.account_tree_outlined, Colors.orange.shade800),
          ]),
          const SizedBox(height: 18),
          const SizedBox(height: 10),
          _panel(children: [
            const Text('توزيع الموظفين النشطين حسب الإدارة', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (_employeesByDepartment.isEmpty)
              const Text('لا توجد بيانات موظفين نشطين موزعة على الإدارات.')
            else
              ..._employeesByDepartment.take(8).map((entry) => _progressRow(entry.key, entry.value, _activeEmployees, _hrPurple)),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('مؤشرات الالتزام والتشغيل', Icons.fact_check_outlined),
          LayoutBuilder(builder: (context, c) {
            final count = c.maxWidth > 900 ? 4 : c.maxWidth > 550 ? 2 : 1;
            return GridView.count(
              crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: count == 1 ? 3.4 : 2.2,
              children: [
                _metric('عقود تنتهي خلال 30 يومًا', '$_contractsExpiringSoon', 'من الموظفين النشطين', Icons.event_busy_outlined, _hrOrange),
                _metric('عقود سارية', '$_contractsActive', 'من الموظفين النشطين بعقد', Icons.verified_outlined, Colors.green.shade700),
                _metric('عقود منتهية', '$_contractsExpired', 'تحتاج مراجعة فورية', Icons.warning_amber_outlined, Colors.red.shade700),
                _metric('عقود بلا تاريخ نهاية / نوع', '$_contractsMissing', 'تحتاج استكمال البيانات', Icons.assignment_late_outlined, _hrPink),
                _metric('موظفون بلا عقد', '$_employeesWithoutContract', 'موظفون نشطون دون عقد', Icons.assignment_ind_outlined, Colors.blueGrey),
                _metric('نواقص مسوغات التعيين', '$_employeesMissingRequiredDocuments', 'وفق متطلبات الوظيفة', Icons.folder_off_outlined, _hrPink),
                _metric('تأخيرات الشهر', '$_lateAttendanceCount', 'من سجلات الحضور المسجلة', Icons.schedule_outlined, _hrPurple),
                _metric('غياب الشهر', '$_absenceAttendanceCount', 'من سجلات الحضور المسجلة', Icons.person_off_outlined, Colors.red.shade700),
                _metric('إضافي مسجل', '$_overtimeMinutes دقيقة', 'إجمالي دقائق الشهر', Icons.more_time_outlined, Colors.green.shade700),
                _metric('مسيرات غير معتمدة', '$_pendingPayrollRuns', 'من آخر 12 مسيرًا', Icons.receipt_long_outlined, _hrOrange),
              ],
            );
          }),
          const SizedBox(height: 18),
          const SizedBox(height: 18),
          _sectionTitle('التأمينات والرخص والتدريب', Icons.health_and_safety_outlined),
          LayoutBuilder(builder: (context, c) {
            final count = c.maxWidth > 900 ? 4 : c.maxWidth > 550 ? 2 : 1;
            return GridView.count(
              crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: count == 1 ? 3.4 : 2.2,
              children: [
                _metric('تأمين صحي مؤمن', '$_healthInsured', 'موظفون مميزون دون تكرار', Icons.health_and_safety_outlined, _hrPurple),
                _metric('تأمين صحي غير مؤمن', '$_healthUninsured', 'موظفون بحالة غير مؤمن', Icons.health_and_safety_outlined, Colors.red.shade700),
                _metric('تأمين صحي غير مسجل', '$_healthNotRecorded', 'لا يوجد سجل تأمين للموظف', Icons.help_outline, _hrOrange),
                _metric('تأمين اجتماعي مؤمن', '$_socialInsured', 'موظفون مميزون دون تكرار', Icons.account_balance_outlined, _hrPurple),
                _metric('تأمين اجتماعي غير مؤمن', '$_socialUninsured', 'موظفون بحالة غير مؤمن', Icons.account_balance_outlined, Colors.red.shade700),
                _metric('تأمين اجتماعي غير مسجل', '$_socialNotRecorded', 'لا يوجد سجل تأمين للموظف', Icons.help_outline, _hrOrange),
                _metric('طلبات تأمين جارية', '$_insuranceInProgress', 'عدد الموظفين قيد الإجراء', Icons.pending_actions_outlined, _hrPink),
                _metric('رخص منتهية', '$_licensesExpired', 'تحتاج تجديدًا', Icons.assignment_late_outlined, Colors.red.shade700),
                _metric('رخص تنتهي خلال 30 يومًا', '$_licensesExpiringSoon', 'تنبيه مسبق', Icons.event_available_outlined, _hrOrange),
                _metric('تدريب مخطط', '$_trainingPlanned', 'برامج بانتظار التنفيذ', Icons.event_note_outlined, _hrOrange),
                _metric('تدريبات جارية', '$_trainingInProgress', 'برامج تدريب مفتوحة', Icons.school_outlined, _hrPurple),
                _metric('تدريبات مكتملة', '$_trainingCompleted', 'برامج تم إتمامها', Icons.school, Colors.green.shade700),
                _metric('شهادات تدريب منتهية', '$_trainingCertificatesExpired', 'تحتاج تحديثًا', Icons.workspace_premium_outlined, Colors.red.shade700),
                _metric('شهادات تدريب تنتهي قريبًا', '$_trainingCertificatesExpiring', 'خلال 30 يومًا', Icons.workspace_premium_outlined, _hrPink),
              ],
            );
          }),
          const SizedBox(height: 18),
          _sectionTitle('التوظيف والاستقالات ودوران العمالة', Icons.groups_outlined),
          _panel(children: [
            _progressRow('طلبات التوظيف المفتوحة', _candidateOpen, _candidates.length, _hrPurple),
            _progressRow('مقبولون', _candidateCount('accepted'), _candidates.length, Colors.green.shade700),
            _progressRow('في مرحلة الفرز', _candidateScreening, _candidates.length, _hrOrange),
            _progressRow('في مرحلة المقابلة', _candidateInterviews, _candidates.length, _hrPink),
            _progressRow('مرفوضون', _candidateCount('rejected'), _candidates.length, Colors.red.shade700),
            _alert('نسبة القبول من القرارات المحسومة', '${_candidateAcceptanceRate.toStringAsFixed(1)}% من القرارات التي حُسمت بالقبول أو الرفض.', _candidateDecided == 0 ? Colors.blueGrey : Colors.green.shade700),
            _alert('الاستقالات', '$_resignationsInPeriod استقالة خلال آخر $_analysisPeriodDays يومًا.', _resignationsInPeriod > 0 ? _hrOrange : Colors.blueGrey),
            _alert('انتهاء الخدمة', '$_separationsInPeriod حركة انتهاء خدمة خلال الفترة، مقابل $_hiresInPeriod تعيينًا.', _separationsInPeriod > 0 ? _hrOrange : Colors.blueGrey),
            _alert('معدل دوران العمالة', '$_turnoverRateDisplay. يُحسب على متوسط قوة العمل التقديرية خلال الفترة المحددة.', Colors.blueGrey),
          ]),
          const SizedBox(height: 10),
          _panel(children: [
            Text('الاستقالات وإنهاء الخدمة حسب الإدارة — آخر $_analysisPeriodDays يومًا', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (_separationsByDepartment.isEmpty)
              const Text('لا توجد حركات انتهاء خدمة مسجلة خلال فترة التحليل المحددة.')
            else
              ..._separationsByDepartment.take(8).map((entry) => _progressRow(entry.key, entry.value, _separationsInPeriod, _hrOrange)),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('الرواتب وتكلفة العمالة', Icons.payments_outlined),
          _panel(children: [
            if (_latestPayrollRun == null)
              const Text('لا توجد مسيرات رواتب مسجلة لعرض إجمالي الرواتب.')
            else ...[
              _alert('إجمالي الاستحقاقات في أحدث مسير', _moneyLabel(_latestPayrollRun!['gross_total']), Colors.green.shade700),
              _alert('صافي الرواتب في أحدث مسير', _moneyLabel(_latestPayrollRun!['net_total']), _hrPurple),
              _alert('بيانات المسير', 'الفترة: ${_latestPayrollRun!['period_start'] ?? 'غير محددة'} إلى ${_latestPayrollRun!['period_end'] ?? 'غير محددة'} • عدد الموظفين: ${_latestPayrollRun!['employee_count'] ?? 'غير محدد'} • الحالة: ${_hrStatusLabel(_latestPayrollRun!['status']?.toString() ?? '')}.', Colors.blueGrey),
            ],
            const Text('هذه أرقام أحدث مسير محمّل وليست متوسط تكلفة الموظف أو مقارنة تكلفة العمالة بالمبيعات.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.5)),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('مؤشرات إدارية متقدمة', Icons.analytics_outlined),
          _panel(children: [
            _progressRow('التعيينات خلال الفترة', _hiresInPeriod, _hiresInPeriod + _separationsInPeriod, Colors.green.shade700),
            _progressRow('حركات انتهاء الخدمة خلال الفترة', _separationsInPeriod, _hiresInPeriod + _separationsInPeriod, _hrOrange),
            _alert('جودة بيانات الموظفين', 'موظفون بلا وظيفة محددة: $_employeesWithoutJob، وملفات غير نشطة: $_inactiveEmployees، ونواقص مسوغات التعيين: $_employeesMissingRequiredDocuments.', _employeesWithoutJob + _employeesMissingRequiredDocuments > 0 ? _hrOrange : Colors.blueGrey),
            _alert('التأمين الصحي والاجتماعي', 'غير مسجل صحيًا: $_healthNotRecorded، وغير مسجل اجتماعيًا: $_socialNotRecorded. الأعداد محسوبة على الموظفين النشطين وبحسب سجلاتهم الفردية.', _healthNotRecorded + _socialNotRecorded > 0 ? _hrOrange : Colors.blueGrey),
            _alert('مؤشرات تتطلب استكمال مصدر البيانات', 'العجز مقابل الملاك المعتمد يحتاج عددًا مستهدفًا لكل وظيفة. متابعة فترة الاختبار تحتاج تاريخ بداية ونهاية ونتيجة. تقييم الأداء وإصابات العمل وتكلفة التوظيف ومقارنة تكلفة العمالة بالمبيعات تحتاج سجلات متخصصة قبل احتسابها.', Colors.blueGrey),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('إدارة وتسجيل بيانات الموارد البشرية', Icons.add_task_outlined),
          if (widget.canManage) Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _loading ? null : _addCompliance, icon: const Icon(Icons.health_and_safety_outlined), label: const Text('إضافة تأمين / رخصة')),
            OutlinedButton.icon(onPressed: _loading ? null : _addTraining, icon: const Icon(Icons.school_outlined), label: const Text('تسجيل تدريب')),
            OutlinedButton.icon(onPressed: _loading ? null : _addCandidate, icon: const Icon(Icons.person_search_outlined), label: const Text('إضافة متقدم وظيفة')),
            OutlinedButton.icon(onPressed: _loading ? null : _addMovement, icon: const Icon(Icons.swap_horiz_outlined), label: const Text('تسجيل حركة موظف')),
          ]),

          if (widget.canManage) ...[
            const SizedBox(height: 18),
            _sectionTitle('متابعة وتحديث السجلات الحديثة', Icons.manage_history_outlined),
            _panel(children: [
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('طلبات التوظيف (${_candidates.length})'),
                children: _candidates.take(8).map((row) => ListTile(
                  dense: true,
                  title: Text(row['candidate_name']?.toString() ?? 'متقدم بدون اسم'),
                  subtitle: Text('الحالة: ${_hrStatusLabel(row['status']?.toString() ?? '')}'),
                  trailing: TextButton(
                    onPressed: () => _changeHrRecordStatus(
                      table: 'erp_hr_recruitment_candidates', id: row['id'].toString(),
                      current: row['status']?.toString() ?? 'new', recruitment: true,
                      options: const [MapEntry('new','جديد'),MapEntry('screening','فرز'),MapEntry('interview','مقابلة'),MapEntry('accepted','مقبول'),MapEntry('rejected','مرفوض'),MapEntry('withdrawn','منسحب')],
                    ),
                    child: const Text('تحديث'),
                  ),
                )).toList(),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('سجلات التأمين والرخص (${_compliance.length})'),
                children: _compliance.take(8).map((row) => ListTile(
                  dense: true,
                  title: Text('${_employeeLabel(row['employee_id'])} • ${row['record_type'] == 'license' ? 'رخصة' : row['record_type'] == 'health_insurance' ? 'تأمين صحي' : 'تأمين اجتماعي'}'),
                  subtitle: Text('الحالة: ${_hrStatusLabel(row['status']?.toString() ?? '')} • انتهاء: ${row['expires_on'] ?? 'غير محدد'}'),
                  trailing: TextButton(
                    onPressed: () => _changeHrRecordStatus(
                      table: 'erp_hr_employee_compliance', id: row['id'].toString(),
                      current: row['status']?.toString() ?? 'in_progress',
                      options: const [MapEntry('insured','مؤمن'),MapEntry('uninsured','غير مؤمن'),MapEntry('in_progress','جارٍ'),MapEntry('valid','سارية'),MapEntry('expired','منتهية'),MapEntry('not_required','غير مطلوب')],
                    ),
                    child: const Text('تحديث'),
                  ),
                )).toList(),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('برامج التدريب (${_training.length})'),
                children: _training.take(8).map((row) => ListTile(
                  dense: true,
                  title: Text('${_employeeLabel(row['employee_id'])} • ${row['course_name'] ?? 'برنامج تدريبي'}'),
                  subtitle: Text('الحالة: ${_hrStatusLabel(row['status']?.toString() ?? '')}'),
                  trailing: TextButton(
                    onPressed: () => _changeHrRecordStatus(
                      table: 'erp_hr_training_records', id: row['id'].toString(),
                      current: row['status']?.toString() ?? 'planned',
                      options: const [MapEntry('planned','مخطط'),MapEntry('in_progress','جارٍ'),MapEntry('completed','مكتمل'),MapEntry('expired','منتهي'),MapEntry('cancelled','ملغي')],
                    ),
                    child: const Text('تحديث'),
                  ),
                )).toList(),
              ),
            ]),
          ],
          const SizedBox(height: 18),
          _sectionTitle('تنبيهات ومتابعات مدير الموارد البشرية', Icons.notifications_active_outlined),
          _panel(children: [
            _alert('اكتمال الهيكل التنظيمي', _departmentsWithoutJobs + _unassignedJobs == 0 && _departments.isNotEmpty && _jobs.isNotEmpty
                ? 'لا توجد فجوات ربط ظاهرة في البيانات الحالية.' : 'توجد إدارات بلا وظائف أو وظائف غير مرتبطة بإدارة؛ راجع الهيكل الوظيفي.', _departmentsWithoutJobs + _unassignedJobs == 0 ? Colors.green : Colors.orange),
            _alert('سجلات موظفين مؤقتة', 'تم استبعاد $_temporaryEmployees سجلًا تجريبيًا موسومًا ببيانات أولية مؤقتة من مؤشرات القوى العاملة والعقود والتأمينات والتوظيف؛ راجعها واستبدلها ببيانات فعلية قبل الاعتماد.', _temporaryEmployees > 0 ? Colors.orange : Colors.green),
            _alert('التعيينات المستقبلية', 'عدد الموظفين الحقيقيين المسجلين بتاريخ تعيين مستقبلي: $_upcomingHires. لا يدخلون في عدد القوة العاملة الحالية حتى تاريخ مباشرة العمل.', _upcomingHires > 0 ? Colors.blueGrey : Colors.green),
            _alert('ملفات الموظفين غير النشطة', 'عدد الملفات غير النشطة: $_inactiveEmployees. راجع أسباب الإيقاف أو انتهاء الخدمة.', Colors.orange),
            _alert('العقود', 'عقود سارية: $_contractsActive، تنتهي خلال 30 يومًا: $_contractsExpiringSoon، منتهية: $_contractsExpired، وتحتاج استكمال النوع أو تاريخ النهاية: $_contractsMissing. موظفون بلا عقد: $_employeesWithoutContract.', _contractsExpired + _contractsExpiringSoon + _contractsMissing + _employeesWithoutContract > 0 ? Colors.orange : Colors.green),
            _alert('مسوغات التعيين', 'عدد الموظفين الذين تنقص ملفاتهم مستندات مطلوبة حسب الوظيفة: $_employeesMissingRequiredDocuments. راجع متطلبات الوظائف وسجل مستندات الموظفين.', _employeesMissingRequiredDocuments > 0 ? Colors.orange : Colors.green),
            _alert('الحضور والانصراف', 'خلال الشهر الحالي: $_absenceAttendanceCount حالات غياب و$_lateAttendanceCount حالات تأخير، وإجمالي الوقت الإضافي المسجل $_overtimeMinutes دقيقة.', Colors.blueGrey),
            _alert('التأمينات الصحية والاجتماعية', 'صحي: $_healthInsured مؤمن / $_healthUninsured غير مؤمن / $_healthNotRecorded غير مسجل. اجتماعي: $_socialInsured مؤمن / $_socialUninsured غير مؤمن / $_socialNotRecorded غير مسجل. قيد الإجراء: $_insuranceInProgress.', Colors.blueGrey),
            _alert('الرخص', 'رخص منتهية: $_licensesExpired، ورخص تنتهي خلال 30 يومًا: $_licensesExpiringSoon.', _licensesExpired + _licensesExpiringSoon > 0 ? Colors.orange : Colors.blueGrey),
            _alert('التدريب', 'مخطط: $_trainingPlanned، جارٍ: $_trainingInProgress، مكتمل: $_trainingCompleted، منتهٍ: $_trainingExpired، شهادات منتهية: $_trainingCertificatesExpired، وشهادات تنتهي قريبًا: $_trainingCertificatesExpiring.', Colors.blueGrey),
            _alert('التوظيف والاستقالات', 'متقدمون مفتوحون: $_candidateOpen، مقبولون: ${_candidateCount('accepted')}، مرفوضون: ${_candidateCount('rejected')}، وحركات انتهاء الخدمة خلال آخر 12 شهرًا: $_separationsLast12Months.', Colors.blueGrey),
            _alert('فترة الاختبار', 'غير متاحة كرقم موثوق حاليًا؛ نموذج الموظف لا يحتوي حقولًا منظمة لتاريخ بداية ونهاية الاختبار ونتيجة الاجتياز. لن يتم استنتاج العدد من حالة الموظف العامة.', Colors.blueGrey),
            _alert('طلبات الإجازات', 'طلبات الإجازات غير المحسومة خلال الشهر الحالي: $_pendingLeaveRequests.', _pendingLeaveRequests > 0 ? Colors.orange : Colors.blueGrey),
            _alert('مسيرات الرواتب', 'يوجد $_pendingPayrollRuns مسيرًا غير معتمد ضمن آخر 12 مسيرًا تم تحميلها.', _pendingPayrollRuns > 0 ? Colors.orange : Colors.blueGrey),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('تحليلات إضافية موصى بها', Icons.insights_outlined),
          _panel(children: [
            const Text('تُحسب المؤشرات من سجلات الموظفين والحضور والإجازات والرواتب، ومن سجلات التأمين والرخص والتدريب والتوظيف وحركات انتهاء الخدمة. معدل دوران العمالة تقديري عند عدم اكتمال الحركات التاريخية؛ وتكلفة العمالة مقابل المبيعات وتقييم الأداء تحتاج مصادر بيانات مالية وتقييمات أداء مكتملة.', style: TextStyle(height: 1.7)),
          ]),
          const SizedBox(height: 10),
          const Text('ملاحظة: الأرقام المعروضة مستخرجة من سجلات الموظفين والهيكل الحالية. البنود التي لا يوجد لها مصدر بيانات متكامل تظهر كمتطلبات ربط ولا تتحول إلى أرقام افتراضية.', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.6)),
        ])),
      ]),
    ),
  );

  Widget _sectionTitle(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(children: [Icon(icon, color: _hrPurple, size: 21), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _hrPurple))]),
  );

  bool get _hasCompany => widget.companyId?.trim().isNotEmpty == true;

  Widget _metric(String title, String value, String note, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .18))),
    child: Row(children: [
      CircleAvatar(backgroundColor: color.withValues(alpha: .10), child: Icon(icon, color: color)),
      const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
        Text(_hasCompany ? value : '—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(_hasCompany ? note : 'اختر شركة لعرض المؤشر', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ])),
    ]),
  );

  Widget _panel({required List<Widget> children}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9E2F0))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _progressRow(String label, int value, int total, Color color) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text(_hasCompany ? '$value / $total' : '—', style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: _hasCompany ? ratio : 0, minHeight: 8, color: color, backgroundColor: const Color(0xFFF0EBF4))),
    ]));
  }

  Widget _alert(String title, String detail, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.circle, size: 9, color: color), const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(_hasCompany ? detail : 'اختر شركة نشطة لعرض بيانات الموارد البشرية الفعلية.', style: const TextStyle(color: Colors.black54, height: 1.5))])),
    ]),
  );

  Widget _notice(String message, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(11), margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 19), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(color: color, height: 1.5)))]),
  );
}
