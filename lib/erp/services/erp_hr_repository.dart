import 'package:supabase_flutter/supabase_flutter.dart';

class ErpHrRepository {
  ErpHrRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;

  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول للموارد البشرية.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchEmployees(String companyId) async {
    final rows = await _db.from('erp_employee_directory')
      .select('id, employee_code, full_name, phone, job_title, department_name, hire_date, employment_status, is_active, branch_id')
      .eq('company_id', companyId.trim()).order('employee_code').limit(1000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAttendance(String companyId, {DateTime? day}) async {
    final date = _dateOnly(day ?? DateTime.now());
    final rows = await _db.from('erp_attendance_records')
      .select('id, employee_id, work_date, check_in, check_out, attendance_status, late_minutes, overtime_minutes, notes')
      .eq('company_id', companyId.trim()).eq('work_date', date)
      .order('check_in', ascending: true);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<bool> isNationalIdRequired(String companyId) async {
    final actorId = _db.auth.currentUser?.id;
    final result = await _db.rpc('erp_program_policy_applies', params: {
      'p_company_id': companyId.trim(),
      'p_policy_key': 'national_id_required',
      'p_actor_id': actorId,
    });
    return result == true;
  }

  Future<void> addEmployee({
    required String companyId,
    required String branchId,
    required String employeeCode,
    required String fullName,
    String? nationalId,
    String? phone,
    String? jobTitle,
    String? department,
    String? departmentId,
    String? jobId,
    String? workLocationId,
    DateTime? hireDate,
    double baseSalary = 0,
  }) async {
    if (companyId.trim().isEmpty || branchId.trim().isEmpty || fullName.trim().isEmpty) {
      throw ArgumentError('الشركة والفرع واسم الموظف حقول إلزامية.');
    }
    if (!baseSalary.isFinite || baseSalary < 0) {
      throw ArgumentError('الراتب لا يمكن أن يكون سالبًا أو غير صالح.');
    }
    final normalizedNationalId = (nationalId ?? '').trim();
    if (normalizedNationalId.isNotEmpty &&
        !RegExp(r'^[0-9]{14}$').hasMatch(normalizedNationalId)) {
      throw ArgumentError('الرقم القومي يجب أن يتكون من 14 رقمًا.');
    }

    await _db.rpc('erp_create_employee', params: {
      'p_company_id': companyId.trim(),
      'p_branch_id': branchId.trim(),
      'p_full_name': fullName.trim(),
      'p_national_id': normalizedNationalId.isEmpty ? null : normalizedNationalId,
      'p_phone': _blankToNull(phone),
      'p_job_title': _blankToNull(jobTitle),
      'p_department_name': _blankToNull(department),
      'p_base_salary': baseSalary,
      'p_department_id': _blankToNull(departmentId),
      'p_job_id': _blankToNull(jobId),
      'p_work_location_id': _blankToNull(workLocationId),
      'p_hire_date': hireDate == null ? null : _dateOnly(hireDate),
    });
    // employeeCode is intentionally not sent: the database central-code trigger owns it.
  }

  Future<List<Map<String, dynamic>>> fetchLeaveRequests(String companyId) async {
    final rows = await _db.from('erp_leave_requests')
      .select('id, employee_id, leave_type, starts_on, ends_on, requested_days, reason, status, approved_at')
      .eq('company_id', companyId.trim()).order('starts_on', ascending: false).limit(300);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createLeaveRequest({
    required String companyId,
    required String employeeId,
    required String leaveType,
    required DateTime start,
    required DateTime end,
    required String reason,
  }) async {
    if (start.isAfter(end)) {
      throw ArgumentError('تاريخ بداية الإجازة يجب ألا يتجاوز نهايتها.');
    }
    await _db.rpc('erp_create_leave_request', params: {
      'p_company_id': companyId.trim(),
      'p_employee_id': employeeId,
      'p_leave_type': leaveType,
      'p_starts_on': _dateOnly(start),
      'p_ends_on': _dateOnly(end),
      'p_reason': _blankToNull(reason),
    });
  }

  Future<void> decideLeave(String requestId, String decision) async {
    await _db.rpc('erp_decide_leave_request', params: {
      'p_request_id': requestId,
      'p_decision': decision,
    });
  }

  Future<void> checkIn({
    required String companyId,
    required String employeeId,
    String? notes,
  }) async {
    await _db.rpc('erp_record_hr_direct_check_in', params: {
      'p_company_id': companyId.trim(),
      'p_employee_id': employeeId,
      'p_notes': _blankToNull(notes),
    });
  }

  Future<void> checkOut(String attendanceId) async {
    await _db.rpc('erp_record_hr_direct_check_out', params: {
      'p_attendance_id': attendanceId,
    });
  }

  static String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

  static String? _blankToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
}
