import 'package:flutter/material.dart';
import '../services/erp_operational_documents_repository.dart';

class ErpOperationalDocumentsScreen extends StatefulWidget {
  const ErpOperationalDocumentsScreen({
    super.key,
    this.initialCompanyId,
    this.kind = ErpOperationalKind.purchase,
  });
  final String? initialCompanyId;
  final ErpOperationalKind kind;

  @override
  State<ErpOperationalDocumentsScreen> createState() => _ErpOperationalDocumentsScreenState();
}

class _ErpOperationalDocumentsScreenState extends State<ErpOperationalDocumentsScreen> {
  final _repo = ErpOperationalDocumentsRepository();
  final _company = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  String? _message;

  String get _title => widget.kind == ErpOperationalKind.purchase ? 'مستندات المشتريات' : 'مستندات المبيعات';
  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
  }
  @override
  void dispose() { _company.dispose(); super.dispose(); }

  String _s(dynamic v) => (v ?? '').toString();
  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
  String _money(dynamic v) => _n(v).toStringAsFixed(2);

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولًا.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final rows = await _repo.fetchDocuments(companyId: _company.text, kind: widget.kind);
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل المستندات: $e'; });
    }
  }

  Future<void> _post(Map<String, dynamic> row) async {
    final number = _s(row['document_number']);
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الترحيل'),
      content: Text('سيتم ترحيل المستند $number وإنشاء حركات مخزنية فعلية. لا يمكن إعادة ترحيله بعد نجاح العملية.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ترحيل')),
      ],
    ));
    if (yes != true || !mounted) return;
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      await _repo.postDocument(_s(row['id']), widget.kind);
      if (!mounted) return;
      setState(() { _loading = false; _message = 'تم ترحيل المستند $number وتسجيل حركات المخزون.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر ترحيل المستند: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftCount = _rows.where((r) => ['draft','approved'].contains(_s(r['status']))).length;
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_title, style: const TextStyle(color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('عرض المستندات المسجلة وترحيل المستندات المؤهلة إلى دفتر المخزون من خلال معاملة خادمية واحدة.',
          style: TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 12),
        TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('تحميل المستندات')),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          _metric('المستندات', '${_rows.length}'),
          _metric('جاهز للترحيل', '$draftCount'),
          _metric('مرحّل', '${_rows.where((r) => _s(r['status']) == 'posted').length}'),
        ]),
        const SizedBox(height: 10),
        if (_rows.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مستندات للعرض؛ لم تُضف بيانات تجريبية.')),
        ..._rows.map((r) {
          final status = _s(r['status']);
          final canPost = ['draft','approved'].contains(status);
          final type = _s(r['document_type']);
          final date = _s(r['document_date']);
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.description_outlined, color: Color(0xFF3E007D)),
                const SizedBox(width: 8),
                Expanded(child: Text('مستند رقم ${_s(r['document_number'])}', style: const TextStyle(fontWeight: FontWeight.w900))),
                Chip(label: Text(status)),
              ]),
              const SizedBox(height: 4),
              Text('النوع: $type • التاريخ: $date'),
              const SizedBox(height: 4),
              Text('الإجمالي: ${_money(r['grand_total'])} ج.م • المدفوع: ${_money(r['paid_total'])} ج.م'),
              if (_s(r['notes']).isNotEmpty) Text('ملاحظات: ${_s(r['notes'])}'),
              if (canPost) Align(alignment: Alignment.centerLeft, child: FilledButton.icon(
                onPressed: _loading ? null : () => _post(r),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('ترحيل وتسجيل حركة المخزون'),
              )),
            ],
          )));
        }),
      ],
    ));
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFF7F5FA), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      Text(value, style: const TextStyle(color: Color(0xFF3E007D), fontWeight: FontWeight.w900, fontSize: 18)),
    ]),
  );
}
