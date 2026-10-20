import 'package:flutter/material.dart';
import '../widgets/erp_quick_task_button.dart';
import '../services/erp_fiscal_period_repository.dart';

class ErpFiscalPeriodsScreen extends StatefulWidget {
  const ErpFiscalPeriodsScreen({super.key, this.initialCompanyId});
  final String? initialCompanyId;
  @override
  State<ErpFiscalPeriodsScreen> createState() => _ErpFiscalPeriodsScreenState();
}

class _ErpFiscalPeriodsScreenState extends State<ErpFiscalPeriodsScreen> {
  final _repo = ErpFiscalPeriodRepository();
  final _company = TextEditingController();
  final _name = TextEditingController();
  DateTime _start = DateTime(DateTime.now().year, 1, 1);
  DateTime _end = DateTime(DateTime.now().year, 12, 31);
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }
  @override
  void dispose() { _company.dispose(); _name.dispose(); super.dispose(); }
  String _s(dynamic v) => (v ?? '').toString();
  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) { setState(() => _error = 'أدخل معرّف الشركة أولًا.'); return; }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final rows = await _repo.fetchPeriods(_company.text);
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل الفترات المالية: $e'; });
    }
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: start ? _start : _end,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected == null || !mounted) return;
    setState(() { if (start) { _start = selected; } else { _end = selected; } });
  }

  Future<void> _create() async {
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.createPeriod(companyId: _company.text, name: _name.text, start: _start, end: _end);
      if (!mounted) return;
      _name.clear();
      setState(() { _saving = false; _message = 'تم إنشاء الفترة المالية.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إنشاء الفترة: $e'; });
    }
  }

  Future<void> _close(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إقفال الفترة المالية'),
      content: Text('سيتم إقفال الفترة ' + _s(row['period_name']) + '. لن يمكن فتحها مرة أخرى من شاشة التشغيل، ولن يتم الإقفال إذا بقيت قيود مسودة داخلها.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إقفال')),
      ],
    ));
    if (yes != true || !mounted) return;
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      await _repo.closePeriod(_s(row['id']));
      if (!mounted) return;
      setState(() { _saving = false; _message = 'تم إقفال الفترة المالية.'; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'تعذر إقفال الفترة: $e'; });
    }
  }

  Widget _quickTask(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _previewPeriods() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('معاينة الفترات المالية'),
      content: SizedBox(width: 700, child: _rows.isEmpty ? const Text('لا توجد فترات مالية محمّلة.')
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _rows.map((r) => ListTile(
          dense: true, title: Text(_s(r['period_name'])),
          subtitle: Text('${_s(r['start_date'])} إلى ${_s(r['end_date'])} • ${r['is_closed'] == true ? 'مقفلة' : 'مفتوحة'}'),
        )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(color: const Color(0xFF3E007D), child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('الفترات المالية', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const Text('منع تداخل الفترات والتحقق من المسودات قبل الإقفال.', style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _quickTask('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
            _quickTask('إضافة', Icons.add_circle_outline, const Color(0xFF168447), _saving ? null : () { _name.clear(); setState(() { _error = null; _message = 'نموذج فترة مالية جديدة جاهز.'; }); }),
            _quickTask('حفظ', Icons.save_outlined, const Color(0xFF168447), _saving || _loading ? null : _create),
            _quickTask('معاينة', Icons.visibility_outlined, const Color(0xFF6841A5), _previewPeriods),
            _quickTask('طباعة', Icons.print_outlined, const Color(0xFF4056A1), _previewPeriods),
            _quickTask('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF137C8B), () => setState(() => _message = 'استيراد الفترات من Excel غير مفعّل؛ أنشئ الفترات للتحقق من عدم التداخل.')),
            _quickTask('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFB3261E), _previewPeriods),
          ])),
        ]),
      )),
      const SizedBox(height: 10),
      TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      if (_loading || _saving) const LinearProgressIndicator(),
      if (_error != null) _notice(_error!, Colors.red),
      if (_message != null) _notice(_message!, Colors.green),
      const SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إنشاء فترة مالية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الفترة / السنة المالية')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _pickDate(true), child: Text('تاريخ البداية: ' + _date(_start))),
          OutlinedButton(onPressed: () => _pickDate(false), child: Text('تاريخ النهاية: ' + _date(_end))),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _saving ? null : _create, icon: const Icon(Icons.add), label: const Text('إنشاء الفترة')),
        ],
      ))),
      const SizedBox(height: 12),
      Text('الفترات المسجلة • ' + _rows.length.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      if (_rows.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد فترات محملة.')),
      ..._rows.map((r) => Card(child: ListTile(
        leading: Icon(_s(r['status']) == 'closed' ? Icons.lock : Icons.lock_open, color: _s(r['status']) == 'closed' ? Colors.red : Colors.green),
        title: Text(_s(r['period_name']), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(_s(r['starts_on']) + ' إلى ' + _s(r['ends_on'])),
        trailing: _s(r['status']) == 'open'
          ? OutlinedButton(onPressed: _saving ? null : () => _close(r), child: const Text('إقفال'))
          : const Chip(label: Text('مغلقة')),
      ))),
    ],
  ));

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
