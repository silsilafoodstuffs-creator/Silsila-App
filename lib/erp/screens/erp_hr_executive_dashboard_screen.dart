import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _hrPurple = Color(0xFF3E007D);
const _hrOrange = Color(0xFFFFA015);
const _hrPink = Color(0xFFFF27C3);
const _hrBg = Color(0xFFFAF8FC);

class ErpHrExecutiveDashboardScreen extends StatefulWidget {
  const ErpHrExecutiveDashboardScreen({super.key, this.companyId});
  final String? companyId;

  @override
  State<ErpHrExecutiveDashboardScreen> createState() => _ErpHrExecutiveDashboardScreenState();
}

class _ErpHrExecutiveDashboardScreenState extends State<ErpHrExecutiveDashboardScreen> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _payrollRuns = [];

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
        _db.from('erp_employees').select('id,employee_code,full_name,department_name,job_title,is_active,employment_status,work_unit,job_id,hire_date,contract_type,contract_start_date,contract_end_date').eq('company_id', companyId),
        _db.from('erp_hr_departments').select('id,department_code,name_ar,department_level,parent_id,is_active').eq('company_id', companyId),
        _db.from('erp_hr_jobs').select('id,job_code,name_ar,department_id,is_active,requires_photo,requires_birth_certificate,requires_qualification_certificate,requires_work_card,requires_insurance_printout,requires_military_service,requires_criminal_record,requires_trust_receipt,requires_health_certificate,requires_driving_license,requires_id_copy,requires_bank_account').eq('company_id', companyId),
        _db.from('erp_employee_documents').select('employee_id,doc_type').eq('company_id', companyId),
        _db.from('erp_attendance_records').select('employee_id,work_date,attendance_status,late_minutes,overtime_minutes').eq('company_id', companyId).gte('work_date', dateStart).lte('work_date', dateEnd),
        _db.from('erp_payroll_runs').select('id,run_code,period_start,period_end,status,employee_count,gross_total,net_total').eq('company_id', companyId).order('period_start', ascending: false).limit(12),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = List<Map<String, dynamic>>.from(results[0]);
        _departments = List<Map<String, dynamic>>.from(results[1]);
        _jobs = List<Map<String, dynamic>>.from(results[2]);
        _documents = List<Map<String, dynamic>>.from(results[3]);
        _attendance = List<Map<String, dynamic>>.from(results[4]);
        _payrollRuns = List<Map<String, dynamic>>.from(results[5]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل مؤشرات الموارد البشرية: $e'; });
    }
  }

  int get _activeEmployees => _employees.where((e) => e['is_active'] == true).length;
  int get _inactiveEmployees => _employees.length - _activeEmployees;
  int get _activeDepartments => _departments.where((e) => e['is_active'] != false).length;
  int get _activeJobs => _jobs.where((e) => e['is_active'] != false).length;
  int get _unassignedJobs => _jobs.where((j) => j['department_id'] == null).length;
  int get _departmentsWithoutJobs => _departments.where((d) =>
      !_jobs.any((j) => j['department_id']?.toString() == d['id']?.toString())).length;

  DateTime? _asDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  int get _contractsExpiringSoon => _employees.where((e) {
    final end = _asDate(e['contract_end_date']);
    if (end == null || e['is_active'] != true) return false;
    final days = end.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 30;
  }).length;

  int get _contractsExpired => _employees.where((e) {
    final end = _asDate(e['contract_end_date']);
    return end != null && end.isBefore(DateTime.now()) && e['is_active'] == true;
  }).length;

  int get _contractsWithoutEndDate => _employees.where((e) =>
      e['is_active'] == true && (e['contract_type'] == 'بعقد') &&
      _asDate(e['contract_end_date']) == null).length;

  int get _employeesMissingRequiredDocuments => _employees.where((employee) {
    final job = _jobs.where((j) => j['id']?.toString() == employee['job_id']?.toString()).firstOrNull;
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
  int get _absenceAttendanceCount => _attendance.where((r) => (r['attendance_status']?.toString().toLowerCase() ?? '').contains('absent') || (r['attendance_status']?.toString() ?? '').contains('غائب')).length;
  int get _overtimeMinutes => _attendance.fold<int>(0, (sum, r) => sum + ((r['overtime_minutes'] as num?)?.toInt() ?? 0));
  int get _pendingPayrollRuns => _payrollRuns.where((r) => !const ['approved', 'posted', 'paid'].contains(r['status']?.toString().toLowerCase())).length;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      color: _hrBg,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ملخص إدارة موارد بشرية', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _hrPurple)),
            SizedBox(height: 4),
            Text('لوحة متابعة تنفيذية للقوى العاملة والهيكل والالتزام الوظيفي', style: TextStyle(color: Colors.black54)),
          ])),
          IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث المؤشرات', icon: const Icon(Icons.refresh, color: _hrPurple)),
        ]),
        const SizedBox(height: 14),
        if (_error != null) _notice(_error!, Icons.info_outline, Colors.orange.shade800),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: _hrPurple)))
        else Expanded(child: ListView(children: [
          _sectionTitle('مؤشرات القوى العاملة', Icons.groups_2_outlined),
          LayoutBuilder(builder: (context, c) {
            final count = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
            return GridView.count(
              crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: count == 1 ? 3.3 : 2.25,
              children: [
                _metric('إجمالي الموظفين', _employees.length.toString(), 'كل الملفات المسجلة', Icons.badge_outlined, _hrPurple),
                _metric('موظفون نشطون', _activeEmployees.toString(), 'على رأس العمل حسب حالة الملف', Icons.verified_user_outlined, Colors.green.shade700),
                _metric('غير نشطين', _inactiveEmployees.toString(), 'ملفات غير محددة كنشطة', Icons.person_off_outlined, Colors.red.shade700),
                _metric('الإدارات النشطة', _activeDepartments.toString(), 'من الهيكل التنظيمي', Icons.account_tree_outlined, _hrOrange),
              ],
            );
          }),
          const SizedBox(height: 18),
          _sectionTitle('الهيكل التنظيمي والوظائف', Icons.corporate_fare_outlined),
          _panel(children: [
            _progressRow('الوظائف النشطة', _activeJobs, _jobs.length, _hrPurple),
            _progressRow('إدارات بلا وظائف مرتبطة', _departmentsWithoutJobs, _departments.length, _hrOrange),
            _progressRow('وظائف غير مرتبطة بإدارة', _unassignedJobs, _jobs.length, _hrPink),
            if (_departments.isEmpty || _jobs.isEmpty)
              _notice('استكمل تعريف الإدارات والوظائف وربط كل وظيفة بإدارتها حتى تصبح مؤشرات اكتمال الهيكل دقيقة.', Icons.account_tree_outlined, Colors.orange.shade800),
          ]),
          const SizedBox(height: 18),
          const SizedBox(height: 18),
          _sectionTitle('مؤشرات الالتزام والتشغيل', Icons.fact_check_outlined),
          LayoutBuilder(builder: (context, c) {
            final count = c.maxWidth > 900 ? 4 : c.maxWidth > 550 ? 2 : 1;
            return GridView.count(
              crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: count == 1 ? 3.4 : 2.2,
              children: [
                _metric('عقود تنتهي خلال 30 يومًا', '$_contractsExpiringSoon', 'من الموظفين النشطين', Icons.event_busy_outlined, _hrOrange),
                _metric('عقود منتهية', '$_contractsExpired', 'تحتاج مراجعة فورية', Icons.warning_amber_outlined, Colors.red.shade700),
                _metric('نواقص مسوغات التعيين', '$_employeesMissingRequiredDocuments', 'وفق متطلبات الوظيفة', Icons.folder_off_outlined, _hrPink),
                _metric('تأخيرات الشهر', '$_lateAttendanceCount', 'من سجلات الحضور المسجلة', Icons.schedule_outlined, _hrPurple),
                _metric('غياب الشهر', '$_absenceAttendanceCount', 'من سجلات الحضور المسجلة', Icons.person_off_outlined, Colors.red.shade700),
                _metric('إضافي مسجل', '$_overtimeMinutes دقيقة', 'إجمالي دقائق الشهر', Icons.more_time_outlined, Colors.green.shade700),
                _metric('مسيرات غير معتمدة', '$_pendingPayrollRuns', 'من آخر 12 مسيرًا', Icons.receipt_long_outlined, _hrOrange),
              ],
            );
          }),
          const SizedBox(height: 18),
          _sectionTitle('تنبيهات ومتابعات مدير الموارد البشرية', Icons.notifications_active_outlined),
          _panel(children: [
            _alert('اكتمال الهيكل التنظيمي', _departmentsWithoutJobs + _unassignedJobs == 0 && _departments.isNotEmpty && _jobs.isNotEmpty
                ? 'لا توجد فجوات ربط ظاهرة في البيانات الحالية.' : 'توجد إدارات بلا وظائف أو وظائف غير مرتبطة بإدارة؛ راجع الهيكل الوظيفي.', _departmentsWithoutJobs + _unassignedJobs == 0 ? Colors.green : Colors.orange),
            _alert('ملفات الموظفين غير النشطة', 'عدد الملفات غير النشطة: $_inactiveEmployees. راجع أسباب الإيقاف أو انتهاء الخدمة.', Colors.orange),
            _alert('العقود', 'عقود تنتهي خلال 30 يومًا: $_contractsExpiringSoon، عقود منتهية: $_contractsExpired، وعقود نشطة بلا تاريخ نهاية: $_contractsWithoutEndDate.', _contractsExpired + _contractsExpiringSoon + _contractsWithoutEndDate > 0 ? Colors.orange : Colors.green),
            _alert('مسوغات التعيين', 'عدد الموظفين الذين تنقص ملفاتهم مستندات مطلوبة حسب الوظيفة: $_employeesMissingRequiredDocuments. راجع متطلبات الوظائف وسجل مستندات الموظفين.', _employeesMissingRequiredDocuments > 0 ? Colors.orange : Colors.green),
            _alert('الحضور والانصراف', 'خلال الشهر الحالي: $_absenceAttendanceCount حالات غياب و$_lateAttendanceCount حالات تأخير، وإجمالي الوقت الإضافي المسجل $_overtimeMinutes دقيقة.', Colors.blueGrey),
            _alert('التأمينات الصحية والاجتماعية', 'حالات مؤمن / غير مؤمن / جارٍ تحتاج سجلات تأمين مرتبطة بالموظف؛ لا يتم احتساب أرقام تقديرية.', Colors.blueGrey),
            _alert('التوظيف والاستقالات ومعدل الدوران', 'مؤشرات المتقدمين والقبول والرفض والاستقالات وTurnover تحتاج سجل توظيف وحركات انتهاء خدمة بأسباب وتواريخ.', Colors.blueGrey),
            _alert('مسيرات الرواتب', 'يوجد $_pendingPayrollRuns مسيرًا غير معتمد ضمن آخر 12 مسيرًا تم تحميلها.', _pendingPayrollRuns > 0 ? Colors.orange : Colors.blueGrey),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('تحليلات إضافية موصى بها', Icons.insights_outlined),
          _panel(children: [
            const Text('تُعرض حاليًا مؤشرات الغياب والتأخير والعمل الإضافي من سجلات الحضور، ومؤشرات العقود والمسوغات من ملفات الموظفين. وتظل تكلفة العمالة مقابل المبيعات، ومعدل دوران العمالة، والتوظيف، والتأمينات، والرخص، والتدريب، وتقييم الأداء، وأرصدة الإجازات بحاجة إلى سجلات تشغيلية مخصصة قبل احتسابها.', style: TextStyle(height: 1.7)),
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

  Widget _metric(String title, String value, String note, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .18))),
    child: Row(children: [
      CircleAvatar(backgroundColor: color.withValues(alpha: .10), child: Icon(icon, color: color)),
      const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
      Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$value / $total', style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 8, color: color, backgroundColor: const Color(0xFFF0EBF4))),
    ]));
  }

  Widget _alert(String title, String detail, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.circle, size: 9, color: color), const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(detail, style: const TextStyle(color: Colors.black54, height: 1.5))])),
    ]),
  );

  Widget _notice(String message, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(11), margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 19), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(color: color, height: 1.5)))]),
  );
}
