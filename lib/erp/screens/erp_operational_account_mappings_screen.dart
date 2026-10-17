import 'package:flutter/material.dart';
import '../services/erp_operational_accounting_repository.dart';

class ErpOperationalAccountMappingsScreen extends StatefulWidget {
  const ErpOperationalAccountMappingsScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;
  @override
  State<ErpOperationalAccountMappingsScreen> createState() => _ErpOperationalAccountMappingsScreenState();
}

class _ErpOperationalAccountMappingsScreenState extends State<ErpOperationalAccountMappingsScreen> {
  final _repo = ErpOperationalAccountingRepository();
  final _company = TextEditingController();
  List<Map<String, dynamic>> _accounts = [];
  final Map<String, String?> _selected = {};
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  static const _fields = <(String,String,bool)>[
    ('accounts_receivable_account_id','حساب العملاء (المدينون)',true),
    ('accounts_payable_account_id','حساب الموردين (الدائنون)',true),
    ('sales_revenue_account_id','إيرادات المبيعات',true),
    ('sales_returns_account_id','مرتجعات المبيعات',true),
    ('inventory_account_id','المخزون',true),
    ('cost_of_goods_sold_account_id','تكلفة البضاعة المباعة',true),
    ('purchase_return_variance_account_id','فروق تقييم مرتجع المشتريات',true),
    ('sales_tax_payable_account_id','ضريبة المبيعات المستحقة (اختياري)',false),
    ('purchase_tax_credit_account_id','ضريبة المدخلات/المشتريات (اختياري)',false),
  ];

  @override
  void initState() { super.initState(); _company.text = widget.initialCompanyId ?? ''; }
  @override
  void dispose() { _company.dispose(); super.dispose(); }
  String _s(dynamic v) => (v ?? '').toString();
  String _label(String? id) {
    final rows = _accounts.where((a) => _s(a['id']) == id);
    return rows.isEmpty ? 'اختر حسابًا' : _s(rows.first['account_code']) + ' — ' + _s(rows.first['account_name']);
  }

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final values = await Future.wait([
        _repo.fetchAccounts(_company.text),
        _repo.fetchMapping(_company.text),
      ]);
      if (!mounted) return;
      final accounts = values[0] as List<Map<String, dynamic>>;
      final mapping = values[1] as Map<String, dynamic>?;
      setState(() {
        _accounts = accounts;
        for (final field in _fields) {
          final key = field.$1;
          final saved = mapping == null ? null : _s(mapping[key]);
          _selected[key] = saved != null && saved.isNotEmpty && accounts.any((a) => _s(a['id']) == saved) ? saved : null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل خريطة الحسابات: $e'; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.saveMapping(companyId: _company.text, accountIds: _selected);
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم حفظ خريطة الحسابات التشغيلية.'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر حفظ خريطة الحسابات: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('خريطة الحسابات التشغيلية', style: TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('اربط حسابات الأستاذ التي ستستخدمها قيود فواتير المبيعات والمشتريات والمرتجعات. لن يُنشأ قيد آلي قبل إعداد هذه الخريطة.', style: TextStyle(color: Colors.black54, height: 1.5)),
      const SizedBox(height: 12),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل الحسابات والخريطة')),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      if (_accounts.isNotEmpty) ...[
        const SizedBox(height: 10),
        ..._fields.map((field) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
            value: _selected[field.$1],
            isExpanded: true,
            decoration: InputDecoration(labelText: field.$2, border: const OutlineInputBorder()),
            items: [
              if (!field.$3) const DropdownMenuItem<String>(value: null, child: Text('غير محدد')),
              ..._accounts.map((a) => DropdownMenuItem<String>(
                value: _s(a['id']), child: Text(_label(_s(a['id'])), overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: _saving ? null : (v) => setState(() => _selected[field.$1] = v),
          ),
        )),
        FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('حفظ خريطة الحسابات')),
      ],
      const SizedBox(height: 8),
      const Text('تنبيه: اختر حسابات تحليلية نشطة وغير متطابقة للأدوار المحاسبية المختلفة. اختبر الخريطة على بيانات مراجعة قبل استخدامها في قيود رسمية.', style: TextStyle(color: Colors.black54, height: 1.5)),
    ],
  ));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
