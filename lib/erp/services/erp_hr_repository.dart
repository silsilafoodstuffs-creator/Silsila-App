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

  Future<void> addEmployee({
    required String companyId,
    required String employeeCode,
    required String fullName,
    String? phone,
    String? jobTitle,
    String? department,
    double baseSalary = 0,
  }) async {
    if (companyId.trim().isEmpty || employeeCode.trim().isEmpty || fullName.trim().isEmpty) {
      throw ArgumentError('الشركة وكود الموظف والاسم حقول إلزامية.');
    }
    if (baseSalary < 0) throw ArgumentError('الراتب لا يمكن أن يكون سالبًا.');
    await _db.from('erp_employees').insert({
      'company_id': companyId.trim(),
      'employee_code': employeeCode.trim(),
      'full_name': fullName.trim(),
      'phone': _blankToNull(phone),
      'job_title': _blankToNull(jobTitle),
      'department_name': _blankToNull(department),
      'base_salary': baseSalary,
      'employment_status': 'active',
      'is_active': true,
    });
  }

  Future<void> checkIn({
    required String companyId,
    required String employeeId,
    String? notes,
  }) async {
    final date = _dateOnly(DateTime.now());
    await _db.from('erp_attendance_records').insert({
      'company_id': companyId.trim(),
      'employee_id': employeeId,
      'work_date': date,
      'check_in': DateTime.now().toIso8601String(),
      'attendance_status': 'present',
      'notes': _blankToNull(notes),
    });
  }

  Future<void> checkOut(String attendanceId) async {
    await _db.from('erp_attendance_records').update({
      'check_out': DateTime.now().toIso8601String(),
    }).eq('id', attendanceId).isFilter('check_out', null);
  }

  static String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

  static String? _blankToNull(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
}
