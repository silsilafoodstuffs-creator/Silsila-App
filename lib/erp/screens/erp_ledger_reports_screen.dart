import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/erp_ledger_reports_repository.dart';

enum ErpLedgerReportKind { trialBalance, generalLedger, accountMovement }

class ErpLedgerReportsScreen extends StatefulWidget {
  const ErpLedgerReportsScreen({
    super.key,
    this.kind = ErpLedgerReportKind.trialBalance,
    this.initialCompanyId,
  });

  final ErpLedgerReportKind kind;
  final String? initialCompanyId;

  @override
  State<ErpLedgerReportsScreen> createState() => _ErpLedgerReportsScreenState();
}

class _ErpLedgerReportsScreenState extends State<ErpLedgerReportsScreen> {
  final _repo = ErpLedgerReportsRepository();
  final _company = TextEditingController();
  final _accountId = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _company.text = widget.initialCompanyId ?? '';
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  bool get _trial => widget.kind == ErpLedgerReportKind.trialBalance;
  String get _title => _trial
      ? 'ميزان المراجعة'
      : widget.kind == ErpLedgerReportKind.accountMovement
          ? 'حركة حساب'
          : 'الأستاذ العام';

  @override
  void dispose() {
    _company.dispose();
    _accountId.dispose();
    super.dispose();
  }

  String _date(DateTime? value) => value == null
      ? 'بداية مفتوحة'
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  double _num(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse((value ?? '0').toString()) ?? 0;

  Future<void> _pickDate(bool start) async {
    final initial = (start ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = _trial
          ? await _repo.fetchTrialBalance(
              companyId: _company.text,
              startDate: _start,
              endDate: _end,
            )
          : await _repo.fetchGeneralLedger(
              companyId: _company.text,
              startDate: _start,
              endDate: _end,
              accountId: widget.kind == ErpLedgerReportKind.accountMovement
                  ? _accountId.text
                  : null,
            );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التقرير: $e';
      });
    }
  }

  Widget _reportAction(String label, IconData icon, Color color, VoidCallback action) => FilledButton.icon(
    onPressed: action,
    icon: Icon(icon, size: 15),
    label: Text(label),
    style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );

  void _previewReport() {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('معاينة ' + _title),
      content: SizedBox(width: 720, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('عدد السجلات: ' + _rows.length.toString()),
        const Divider(),
        if (_rows.isEmpty) const Text('لا توجد بيانات للمعاينة.')
        else ..._rows.take(100).map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(row.entries.map((entry) => entry.key + ': ' + (entry.value?.toString() ?? '')).join(' • ')))),
        if (_rows.length > 100) const Text('المعاينة تعرض أول 100 سجل.'),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _printReportPdf() async {
    if (_rows.isEmpty) { setState(() => _message = 'لا توجد بيانات للطباعة.'); return; }
    try {
      final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
      final keys = _rows.first.keys.toList();
      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(theme: pw.ThemeData.withFont(base: font, bold: font), build: (_) => [
        pw.Text('Silsila • ' + _title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(headers: keys, data: _rows.map((row) => keys.map((key) => row[key]?.toString() ?? '').toList()).toList()),
      ]));
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذرت الطباعة أو إنشاء PDF: ' + error.toString());
    }
  }

  Future<void> _importReportExcel() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx'], withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر قراءة ملف Excel.');
      final workbook = excel.Excel.decodeBytes(bytes);
      final sheets = workbook.tables.values.where((sheet) => sheet.rows.isNotEmpty).toList();
      if (sheets.isEmpty) throw StateError('ملف Excel فارغ.');
      final rows = sheets.first.rows;
      final headers = rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
      final imported = <Map<String, dynamic>>[];
      for (final row in rows.skip(1)) {
        final record = <String, dynamic>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          if (headers[i].isNotEmpty) record[headers[i]] = row[i]?.value?.toString() ?? '';
        }
        if (record.values.any((value) => value.toString().trim().isNotEmpty)) imported.add(record);
      }
      if (imported.isEmpty) throw StateError('لم يتم العثور على سجلات بعد صف العناوين.');
      if (!mounted) return;
      setState(() { _rows = imported; _message = 'تم تحميل ' + imported.length.toString() + ' سجلًا من Excel للمعاينة والطباعة فقط؛ اضغط تحديث للعودة إلى بيانات التقرير الفعلية.'; _error = null; });
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر استيراد Excel: ' + error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final debit = _rows.fold<double>(0, (s, r) =>
        s + _num(r[_trial ? 'debit_total' : 'debit']));
    final credit = _rows.fold<double>(0, (s, r) =>
        s + _num(r[_trial ? 'credit_total' : 'credit']));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title, style: const TextStyle(
            color: Color(0xFF3E007D), fontSize: 22, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _reportAction('تحديث', Icons.refresh_rounded, const Color(0xFF2475B8), _loading ? null : _load),
              _reportAction('معاينة', Icons.preview_outlined, const Color(0xFF6E2BA6), _previewReport),
              _reportAction('طباعة', Icons.print_outlined, const Color(0xFFFF27C3), _printReportPdf),
              _reportAction('استيراد Excel', Icons.file_upload_outlined, const Color(0xFF16834A), _importReportExcel),
              _reportAction('طباعة PDF', Icons.picture_as_pdf_outlined, const Color(0xFFD32F2F), _printReportPdf),
            ]),
          ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: Color(0xFF16834A)))),
          const SizedBox(height: 6),
          const Text(
            'يعرض التقرير الحركات المرحلة فقط؛ المسودات والقيود المعكوسة مستبعدة.',
            style: TextStyle(color: Colors.black54),
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
          if (widget.kind == ErpLedgerReportKind.accountMovement) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _accountId,
              decoration: const InputDecoration(
                labelText: 'معرّف الحساب (UUID) — اختياري',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_month),
                label: Text('من: ${_start == null ? 'البداية' : _date(_start)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.calendar_month),
                label: Text('إلى: ${_end == null ? 'النهاية' : _date(_end)}'),
              ),
              TextButton(
                onPressed: () => setState(() { _start = null; _end = null; }),
                child: const Text('كل الفترات'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
                label: const Text('عرض التقرير'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _metric('إجمالي المدين', debit),
              _metric('إجمالي الدائن', credit),
              _metric('الفرق', debit - credit),
              if (!_trial) _metric('عدد السطور المعروضة', _rows.length.toDouble()),
            ]),
            const SizedBox(height: 10),
            if (_trial)
              ..._rows.map((r) => Card(
                child: ListTile(
                  title: Text('${r['account_code'] ?? ''} — ${r['account_name'] ?? ''}'),
                  subtitle: Text('النوع: ${r['account_type'] ?? ''} • طبيعة الرصيد: ${r['normal_balance'] ?? ''}'),
                  trailing: SizedBox(
                    width: 170,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('مدين ${_num(r['debit_total']).toStringAsFixed(2)}'),
                        Text('دائن ${_num(r['credit_total']).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              ))
            else
              ..._rows.map((r) => Card(
                child: ListTile(
                  title: Text('قيد ${r['entry_number'] ?? ''} • ${r['account_code'] ?? ''} — ${r['account_name'] ?? ''}'),
                  subtitle: Text('${r['entry_date'] ?? ''} • ${r['entry_description'] ?? ''}${(r['line_description'] ?? '').toString().isEmpty ? '' : ' • ${r['line_description']}'}'),
                  trailing: SizedBox(
                    width: 145,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('مدين ${_num(r['debit']).toStringAsFixed(2)}'),
                        Text('دائن ${_num(r['credit']).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              )),
          ],
          if (!_loading && _rows.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('أدخل معرّف الشركة واضغط «عرض التقرير». لا تظهر بيانات إلا بعد تهيئة قاعدة البيانات وصلاحيات القراءة.'),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F5FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('$label: ${value.toStringAsFixed(2)} ج.م',
      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3E007D))),
  );
}
