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
      final results = await Future.wait([
        _db.from('erp_employees').select('id,employee_code,full_name,department_name,job_title,is_active,work_unit').eq('company_id', companyId),
        _db.from('erp_hr_departments').select('id,department_code,name_ar,department_level,parent_id,is_active').eq('company_id', companyId),
        _db.from('erp_hr_jobs').select('id,job_code,name_ar,department_id,is_active').eq('company_id', companyId),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = List<Map<String, dynamic>>.from(results[0]);
        _departments = List<Map<String, dynamic>>.from(results[1]);
        _jobs = List<Map<String, dynamic>>.from(results[2]);
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
          _sectionTitle('تنبيهات ومتابعات مدير الموارد البشرية', Icons.notifications_active_outlined),
          _panel(children: [
            _alert('اكتمال الهيكل التنظيمي', _departmentsWithoutJobs + _unassignedJobs == 0 && _departments.isNotEmpty && _jobs.isNotEmpty
                ? 'لا توجد فجوات ربط ظاهرة في البيانات الحالية.' : 'توجد إدارات بلا وظائف أو وظائف غير مرتبطة بإدارة؛ راجع الهيكل الوظيفي.', _departmentsWithoutJobs + _unassignedJobs == 0 ? Colors.green : Colors.orange),
            _alert('ملفات الموظفين غير النشطة', 'عدد الملفات غير النشطة: $_inactiveEmployees. راجع أسباب الإيقاف أو انتهاء الخدمة.', Colors.orange),
            _alert('العقود وفترات التجربة', 'مؤشر العقود وفترات التجربة غير متاح حتى ربط سجل العقود وتواريخ بداية ونهاية العقد وفترة الاختبار.', Colors.blueGrey),
            _alert('الرخص والمستندات', 'يلزم استكمال تواريخ انتهاء الرخص والمستندات وربطها بملف الموظف لتوليد تنبيهات الاستحقاق والانتهاء.', Colors.blueGrey),
            _alert('التأمينات الصحية والاجتماعية', 'حالات مؤمن / غير مؤمن / جارٍ تحتاج سجلات تأمين مرتبطة بالموظف؛ لا يتم احتساب أرقام تقديرية.', Colors.blueGrey),
            _alert('التوظيف والاستقالات ومعدل الدوران', 'مؤشرات المتقدمين والقبول والرفض والاستقالات وTurnover تحتاج سجل توظيف وحركات انتهاء خدمة بأسباب وتواريخ.', Colors.blueGrey),
            _alert('مسوغات التعيين', 'راجع اكتمال المستندات المطلوبة لكل موظف وفق متطلبات الوظيفة، بعد ربط سجل المسوغات بملف الموظف.', Colors.blueGrey),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('تحليلات إضافية موصى بها', Icons.insights_outlined),
          _panel(children: [
            const Text('تتضمن النسخة التشغيلية المستهدفة: معدل الغياب والتأخير، تكلفة العمالة كنسبة من المبيعات، متوسط مدة شغل الوظيفة، معدل الاحتفاظ بالموظفين، أسباب ترك العمل، توزيع الأعمار والخبرات، فجوات المهارات، انتهاء شهادات السلامة والتدريب، تقييم الأداء، العمل الإضافي، أرصدة الإجازات، ومقارنة القوى العاملة بالخطة المعتمدة.', style: TextStyle(height: 1.7)),
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
