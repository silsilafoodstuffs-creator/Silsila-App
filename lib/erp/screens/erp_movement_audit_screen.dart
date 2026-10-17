import 'package:flutter/material.dart';
import '../services/erp_movement_audit_repository.dart';
import 'erp_accounts_screen.dart';
import 'erp_journal_entries_screen.dart';
import 'erp_inventory_screen.dart';
import 'erp_cash_vouchers_screen.dart';
import 'erp_cashboxes_screen.dart';
import 'erp_operational_documents_screen.dart';
import 'erp_hr_operations_screen.dart';
import 'erp_payroll_screen.dart';
import 'erp_fiscal_periods_screen.dart';
import 'erp_inventory_master_screen.dart';

class ErpMovementAuditScreen extends StatefulWidget {
  const ErpMovementAuditScreen({super.key});

  @override
  State<ErpMovementAuditScreen> createState() => _ErpMovementAuditScreenState();
}

class _ErpMovementAuditScreenState extends State<ErpMovementAuditScreen> {
  final _repo = ErpMovementAuditRepository();
  final _company = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _area = 'كل الحركات';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _issues = [];

  static const _areas = [
    'كل الحركات',
    'القيود المحاسبية',
    'الحسابات',
    'الخزائن',
    'البنوك',
    'المخازن',
    'الأصناف',
    'مجموعات الأصناف',
    'الفترات المالية',
    'المخزون',
    'المبيعات',
    'المشتريات',
    'الموظفون',
    'الحضور والانصراف',
    'الإجازات',
    'الرواتب',
    'سندات الخزائن',
  ];

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _chooseDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.runAudit(
        companyId: _company.text,
        area: _area,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _issues = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تنفيذ الفحص: $e';
      });
    }
  }

  Future<void> _openFix(Map<String, dynamic> issue) async {
    final route = (issue['repair_route'] ?? '').toString();
    final code = (issue['issue_code'] ?? '').toString();
    if (code == 'JOURNAL_CLOSED_PERIOD' || code == 'JOURNAL_NO_FISCAL_PERIOD') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpFiscalPeriodsScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'journal_draft' || route == 'journal_reversal') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpJournalEntriesScreen(
          initialCompanyId: _company.text.trim(),
          initialEntryId: (issue['document_id'] ?? '').toString(),
        ),
      ));
    } else if (route == 'cashboxes') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpCashboxesScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'cash_vouchers') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpCashVouchersScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'purchases') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpOperationalDocumentsScreen(
          initialCompanyId: _company.text.trim(),
          kind: ErpOperationalKind.purchase,
          initialDocumentId: (issue['document_id'] ?? '').toString().isEmpty ? null : (issue['document_id'] ?? '').toString(),
        ),
      ));
    } else if (route == 'sales') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpOperationalDocumentsScreen(
          initialCompanyId: _company.text.trim(),
          kind: ErpOperationalKind.sales,
          initialDocumentId: (issue['document_id'] ?? '').toString().isEmpty ? null : (issue['document_id'] ?? '').toString(),
        ),
      ));
    } else if (route == 'hr' && (issue['area'] ?? '').toString() == 'الرواتب') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpPayrollScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'hr') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpHrOperationsScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'fiscal_periods') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpFiscalPeriodsScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'warehouses') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpInventoryMasterScreen(initialCompanyId: _company.text.trim(), initialView: 'warehouses'),
      ));
    } else if (route == 'groups') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpInventoryMasterScreen(initialCompanyId: _company.text.trim(), initialView: 'groups'),
      ));
    } else if (route == 'items') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpInventoryMasterScreen(initialCompanyId: _company.text.trim(), initialView: 'items'),
      ));
    } else if (route == 'inventory') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpInventoryScreen(initialCompanyId: _company.text.trim()),
      ));
    } else if (route == 'accounts') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ErpAccountsScreen(
          initialCompanyId: _company.text.trim(),
          initialSearch: (issue['document_number'] ?? '').toString(),
        ),
      ));
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('خطوة الضبط المطلوبة'),
          content: Text(
            'المشكلة: ${issue['issue_message']}\n\n'
            'لا توجد شاشة ضبط مباشرة لهذا النوع حتى الآن. '
            'تم تسجيل الملاحظة من قاعدة البيانات فقط؛ لن يجري تعديل أي بيانات تلقائيًا.\n'
            'رمز الفحص: $code',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      );
    }
    if (mounted) _run();
  }

  @override
  Widget build(BuildContext context) {
    final errors = _issues.where((r) => r['severity'] == 'خطأ').length;
    final warnings = _issues.where((r) => r['severity'] == 'تحذير').length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اختبار ومراجعة الحركات',
            style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'فحص فعلي للبيانات المتاحة في قاعدة ERP، مع تقرير بكل ملاحظة وزر للانتقال إلى شاشة المعالجة المناسبة.',
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'معرّف الشركة (UUID)',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _area,
            decoration: const InputDecoration(labelText: 'مجال الفحص', border: OutlineInputBorder()),
            items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (v) => setState(() => _area = v ?? _area),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _chooseDate(true),
              icon: const Icon(Icons.calendar_month),
              label: Text('من: ${_dateText(_startDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _chooseDate(false),
              icon: const Icon(Icons.calendar_month),
              label: Text('إلى: ${_dateText(_endDate)}'),
            ),
            TextButton(
              onPressed: () => setState(() { _startDate = null; _endDate = null; }),
              child: const Text('من بداية النظام'),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _run,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('فحص وعرض التقرير'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3E007D)),
            ),
          ]),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'نطاق الفحص الحالي: القيود اليومية وتوازنها وصلاحية حساباتها والفترات المالية، سلامة العلاقات في شجرة الحسابات، وربط الخزائن والبنوك بحسابات الأستاذ. حركات المبيعات والمشتريات والمخزون والموظفين تحتاج جداولها الفعلية قبل إضافتها للفحص؛ لن نعرض نتائج تجريبية على أنها تدقيق حقيقي.',
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _error == null && _issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _metric('الملاحظات', _issues.length.toString(), const Color(0xFF3E007D)),
              _metric('أخطاء', errors.toString(), Colors.red),
              _metric('تحذيرات', warnings.toString(), const Color(0xFFFFA015)),
            ]),
            const SizedBox(height: 8),
            ..._issues.map((issue) {
              final isError = issue['severity'] == 'خطأ';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${issue['area'] ?? ''} • ${issue['document_number'] ?? ''} • ${issue['document_title'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E007D)),
                      ),
                      const SizedBox(height: 5),
                      Text('التاريخ: ${issue['document_date'] ?? '—'} • الكود: ${issue['issue_code'] ?? ''}'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isError ? Colors.red : const Color(0xFFFFA015)).withOpacity(.09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${issue['severity'] ?? ''}: ${issue['issue_message'] ?? ''}',
                          style: TextStyle(color: isError ? Colors.red : const Color(0xFF9A5A00), fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonalIcon(
                          onPressed: _loading ? null : () => _openFix(issue),
                          icon: const Icon(Icons.build_circle_outlined),
                          label: const Text('فتح شاشة الضبط'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (!_loading && _error == null && _issues.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text('لا توجد ملاحظات ضمن النطاق المحدد، أو لم توجد بيانات متاحة للفحص. تأكد من اختيار الشركة وتطبيق ملف SQL ومنح المستخدم صلاحيات القراءة.', textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(10)),
    child: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
  );
}
