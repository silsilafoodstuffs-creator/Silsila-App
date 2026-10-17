import 'package:supabase_flutter/supabase_flutter.dart';

class ErpPayrollRepository {
  ErpPayrollRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }
  SupabaseClient get _db {
    final db = _client;
    if (db == null) throw StateError('Supabase غير مهيأ؛ تعذر الوصول لمسيرات الرواتب.');
    return db;
  }

  Future<List<Map<String, dynamic>>> fetchRuns(String companyId) async {
    final rows = await _db.from('erp_payroll_runs')
      .select('id, company_id, run_code, period_start, period_end, status, employee_count, gross_total, deduction_total, net_total, expense_account_id, payable_account_id, deductions_account_id, journal_entry_id')
      .eq('company_id', companyId.trim()).order('period_start', ascending: false).limit(300);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEmployees(String companyId) async {
    final rows = await _db.from('erp_employee_directory')
      .select('id, employee_code, full_name, base_salary:employee_code')
      .eq('company_id', companyId.trim()).eq('employment_status', 'active').eq('is_active', true)
      .order('employee_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchEmployeeSalaries(String companyId) async {
    final rows = await _db.from('erp_employees')
      .select('id, employee_code, full_name, base_salary')
      .eq('company_id', companyId.trim()).eq('employment_status', 'active').eq('is_active', true)
      .order('employee_code');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAccounts(String companyId) async {
    final rows = await _db.from('erp_accounts')
      .select('id, account_code, account_name')
      .eq('company_id', companyId.trim()).eq('is_active', true).eq('is_postable', true)
      .order('account_code').limit(2000);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchLines(String runId) async {
    final rows = await _db.from('erp_payroll_lines')
      .select('id, employee_id, basic_amount, allowances, commissions, overtime_amount, deductions, gross_amount, net_amount')
      .eq('payroll_run_id', runId).order('created_at');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> createRun({
    required String companyId,
    required String runCode,
    required DateTime start,
    required DateTime end,
    required String expenseAccountId,
    required String payableAccountId,
    required String deductionsAccountId,
  }) async {
    if (runCode.trim().isEmpty || start.isAfter(end)) throw ArgumentError('راجع كود المسير والفترة.');
    await _db.from('erp_payroll_runs').insert({
      'company_id': companyId.trim(),
      'run_code': runCode.trim(),
      'period_start': _dateOnly(start),
      'period_end': _dateOnly(end),
      'expense_account_id': expenseAccountId,
      'payable_account_id': payableAccountId,
      'deductions_account_id': deductionsAccountId,
      'status': 'draft',
    });
  }

  Future<void> addLine({
    required String companyId,
    required String runId,
    required String employeeId,
    required double basic,
    required double allowances,
    required double commissions,
    required double overtime,
    required double deductions,
  }) async {
    final gross = basic + allowances + commissions + overtime;
    final net = gross - deductions;
    if (basic < 0 || allowances < 0 || commissions < 0 || overtime < 0 ||
        deductions < 0 || deductions > gross) {
      throw ArgumentError('راجع مكونات الراتب والاستقطاعات.');
    }
    await _db.from('erp_payroll_lines').insert({
      'company_id': companyId.trim(),
      'payroll_run_id': runId,
      'employee_id': employeeId,
      'basic_amount': basic,
      'allowances': allowances,
      'commissions': commissions,
      'overtime_amount': overtime,
      'deductions': deductions,
      'gross_amount': gross,
      'net_amount': net,
    });
  }

  Future<void> recalculate(String runId) async {
    await _db.rpc('erp_recalculate_payroll_run', params: {'p_run_id': runId});
  }
  Future<void> approve(String runId) async {
    await _db.rpc('erp_approve_payroll_run', params: {'p_run_id': runId});
  }
  Future<void> post(String runId) async {
    await _db.rpc('erp_post_payroll_run', params: {'p_run_id': runId});
  }

  static String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
}
