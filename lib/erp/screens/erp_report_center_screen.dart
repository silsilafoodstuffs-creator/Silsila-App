import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only report viewer for ERP reports that do not yet have a dedicated
/// calculation-specific report implementation. It reads tenant-scoped source
/// records and never writes to operational tables.
class ErpReportCenterScreen extends StatefulWidget {
  const ErpReportCenterScreen({
    super.key,
    required this.companyId,
    required this.reportName,
  });

  final String? companyId;
  final String reportName;

  @override
  State<ErpReportCenterScreen> createState() => _ErpReportCenterScreenState();
}

class _ErpReportCenterScreenState extends State<ErpReportCenterScreen> {
  bool _loading = false;
  String? _error;
  String? _sourceTable;
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  String _search = '';

  static const Map<String, List<String>> _sources = <String, List<String>>{
    'تقرير المستخدمين': <String>['erp_users'],
    'تقرير نشاط النظام': <String>['erp_audit_logs', 'erp_activity_logs', 'erp_user_activity_logs'],
    'تقرير استهلاك API': <String>['erp_api_usage_logs', 'erp_api_logs', 'erp_integration_logs'],
    'تقرير أخطاء التكامل': <String>['erp_integration_logs', 'erp_api_logs'],
    'تقرير التطبيقات': <String>['erp_apps', 'erp_managed_apps', 'erp_app_registry'],
    'تقرير الصلاحيات': <String>['erp_user_permissions', 'erp_user_permission_matrix', 'erp_app_permissions'],
    'تقرير تغييرات الإعدادات': <String>['erp_app_activity_logs', 'erp_audit_logs'],
    'ميزان المراجعة': <String>['erp_journal_entries'],
    'الأستاذ العام': <String>['erp_journal_entries'],
    'قائمة الدخل': <String>['erp_journal_entries'],
    'الميزانية العمومية': <String>['erp_journal_entries'],
    'حركة حساب': <String>['erp_journal_entries'],
    'أرصدة الخزائن': <String>['erp_cashboxes'],
    'كشف حساب خزينة': <String>['erp_cash_vouchers'],
    'كشف حساب بنك': <String>['erp_cash_vouchers'],
    'مؤشرات الأداء الرئيسية': <String>['erp_sales_documents', 'erp_purchase_documents'],
    'التدفقات النقدية': <String>['erp_cash_vouchers'],
    'تحليل الربحية': <String>['erp_sales_documents'],
    'حركة المبيعات والمخزون': <String>['erp_inventory_movements', 'erp_inventory_transactions'],
    'أداء الفروع': <String>['erp_branches'],
    'أرباح وخسائر الفروع': <String>['erp_sales_documents'],
    'حركة التحويلات': <String>['erp_inventory_movements', 'erp_inventory_transactions'],
    'أرصدة الأصناف': <String>['erp_inventory_balances'],
    'كارت الصنف': <String>['erp_inventory_movements', 'erp_inventory_transactions'],
    'الجرد والفروق': <String>['erp_inventory_movements', 'erp_inventory_transactions'],
    'الأصناف الراكدة': <String>['erp_inventory_balances'],
    'الأصناف قاربت على النفاد': <String>['erp_inventory_balances'],
    'تنبيهات إعادة الطلب': <String>['erp_inventory_balances'],
    'تواريخ الصلاحية': <String>['erp_inventory_batches', 'erp_inventory_lots'],
    'تنبيهات قرب انتهاء الصلاحية': <String>['erp_inventory_batches', 'erp_inventory_lots'],
    'أرصدة التشغيلات': <String>['erp_inventory_batches', 'erp_inventory_lots'],
    'تحليل المشتريات': <String>['erp_purchase_documents'],
    'مقارنة أسعار الموردين': <String>['erp_purchase_document_lines', 'erp_purchase_items'],
    'أعمار ديون الموردين': <String>['erp_purchase_documents'],
    'أرصدة الموردين': <String>['erp_purchase_documents'],
    'أداء الموردين': <String>['erp_purchase_documents'],
    'الموردون حسب النشاط': <String>['erp_parties'],
    'المبيعات اليومية': <String>['erp_sales_documents'],
    'ربحية المبيعات': <String>['erp_sales_documents'],
    'مبيعات حسب الفرع': <String>['erp_sales_documents'],
    'أداء المندوبين': <String>['erp_sales_documents', 'erp_sales_representatives'],
    'الطلبات المتأخرة': <String>['erp_sales_documents'],
    'أرصدة العملاء': <String>['erp_sales_documents'],
    'أعمار الديون': <String>['erp_sales_documents'],
    'أفضل العملاء': <String>['erp_sales_documents'],
    'العملاء المتوقفون': <String>['erp_parties'],
    'تحصيلات يومية': <String>['erp_cash_vouchers'],
    'تصفية المندوبين': <String>['erp_cash_vouchers', 'erp_sales_documents'],
    'تحقيق أهداف العملاء': <String>['erp_sales_targets', 'erp_customer_targets', 'erp_sales_documents'],
    'تقرير العمولات المستحقة': <String>['erp_commission_runs', 'erp_commission_plans', 'erp_sales_documents'],
    'تكلفة خطوط السير': <String>['erp_delivery_routes', 'erp_sales_routes'],
    'كشف العاملين': <String>['erp_employees'],
    'الحضور والغياب': <String>['erp_attendance_records', 'erp_attendance'],
    'رصيد الإجازات': <String>['erp_leave_requests'],
    'انتهاء العقود': <String>['erp_employment_contracts', 'erp_employees'],
    'ملخص الرواتب': <String>['erp_payroll_runs', 'erp_payroll'],
    'مفردات المرتب': <String>['erp_payroll_items', 'erp_payroll_details'],
    'عمولات المندوبين': <String>['erp_commission_runs', 'erp_commission_plans'],
    'أداء العروض': <String>['erp_marketing_campaigns', 'erp_item_offers'],
    'تكلفة الحملات': <String>['erp_marketing_campaigns'],
    'معدل الاستجابة': <String>['erp_crm_tickets', 'erp_support_tickets'],
    'التذاكر المفتوحة': <String>['erp_crm_tickets', 'erp_support_tickets'],
    'زمن الاستجابة': <String>['erp_crm_tickets', 'erp_support_tickets'],
    'رضا العملاء': <String>['erp_crm_tickets', 'erp_customer_feedback'],
    'تقارير الفاتورة الإلكترونية': <String>['erp_einvoice_documents', 'erp_einvoice_submissions'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ErpReportCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.reportName != widget.reportName) {
      _search = '';
      _load();
    }
  }

  Future<void> _load() async {
    final company = (widget.companyId ?? '').trim();
    if (company.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لا توجد شركة محددة. افتح بيانات الشركة وسجّل الدخول بحساب لديه عضوية نشطة ثم أعد المحاولة.';
        _rows = <Map<String, dynamic>>[];
        _sourceTable = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _sourceTable = null;
    });
    final candidates = _sources[widget.reportName] ?? <String>[];
    if (candidates.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'لم يُعرّف مصدر بيانات لهذا التقرير بعد؛ لن يتم عرض سجلات تجريبية بديلة.';
      });
      return;
    }
    Object? lastError;
    for (final table in candidates) {
      try {
        final raw = await Supabase.instance.client
            .from(table)
            .select('*')
            .eq('company_id', company)
            .limit(500);
        if (!mounted) return;
        setState(() {
          _rows = (raw as List)
              .whereType<Map<String, dynamic>>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          _sourceTable = table;
          _loading = false;
          _error = null;
        });
        return;
      } catch (error) {
        lastError = error;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = <Map<String, dynamic>>[];
      _error = 'تعذر قراءة مصدر التقرير. المصادر التي جرى فحصها: ${candidates.join('، ')}. التفاصيل: $lastError';
    });
  }

  List<Map<String, dynamic>> get _visibleRows {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((row) => row.values.any((value) =>
        (value ?? '').toString().toLowerCase().contains(q))).toList();
  }

  List<String> get _columns {
    final keys = <String>[];
    for (final row in _visibleRows.take(100)) {
      for (final key in row.keys) {
        if (!keys.contains(key)) keys.add(key);
      }
    }
    return keys.take(10).toList();
  }

  String _csvCell(dynamic value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  Future<void> _copyCsv() async {
    final rows = _visibleRows;
    final cols = _columns;
    if (rows.isEmpty || cols.isEmpty) return;
    final csv = <String>[
      cols.map(_csvCell).join(','),
      ...rows.map((row) => cols.map((col) => _csvCell(row[col])).join(',')),
    ].join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ بيانات التقرير بصيغة CSV؛ يمكنك لصقها في Excel.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    final columns = _columns;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.analytics_outlined, color: Color(0xFF3E007D), size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.reportName,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF3E007D)))),
                  IconButton(tooltip: 'تحديث', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
                  IconButton(tooltip: 'نسخ CSV إلى Excel', onPressed: rows.isEmpty ? null : _copyCsv, icon: const Icon(Icons.file_download_outlined)),
                ]),
                const SizedBox(height: 6),
                Text(_sourceTable == null ? 'تقرير مرتبط ببيانات قاعدة البيانات' : 'مصدر البيانات: $_sourceTable • السجلات: ${_rows.length}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 8),
                const Text('ملاحظة: هذه شاشة قراءة للبيانات المصدرية. لا تعرض نتائج محاسبية محسوبة أو أرصدة معتمدة ما لم تكن تلك الحسابات مفعّلة في مصدرها المتخصص.',
                    style: TextStyle(color: Color(0xFF7A4A00), fontSize: 12, height: 1.4)),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث داخل التقرير', border: OutlineInputBorder(), isDense: true),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ]),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Card(
            color: const Color(0xFFFFF4F2),
            child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ),
          if (!_loading && _error == null && rows.isEmpty)
            const Expanded(child: Center(child: Text('لا توجد سجلات في مصدر التقرير المحدد.'))),
          if (!_loading && _error == null && rows.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                    columns: columns.map((key) => DataColumn(label: Text(key, style: const TextStyle(fontWeight: FontWeight.w800)))).toList(),
                    rows: rows.map((row) => DataRow(
                      cells: columns.map((key) => DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text((row[key] ?? '—').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      )).toList(),
                    )).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
