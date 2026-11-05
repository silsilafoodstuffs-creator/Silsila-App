import 'dart:convert';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/erp_quick_task_button.dart';
import '../services/erp_whatsapp_contacts_repository.dart';

class ErpWhatsappContactsScreen extends StatefulWidget {
  const ErpWhatsappContactsScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpWhatsappContactsScreen> createState() => _ErpWhatsappContactsScreenState();
}

class _ErpWhatsappContactsScreenState extends State<ErpWhatsappContactsScreen> {
  static const purple = Color(0xFF3E007D);
  static const orange = Color(0xFFFFA015);
  final _repo = ErpWhatsappContactsRepository();
  final _company = TextEditingController();
  final _source = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  final Set<String> _selected = {};
  bool _loading = false, _saving = false;
  String? _error, _message;
  String _filter = 'الكل';

  @override
  void initState() {
    super.initState();
    _company.text = widget.companyId ?? '';
    if (_company.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _company.dispose();
    _source.dispose();
    _search.dispose();
    super.dispose();
  }

  String _s(dynamic value) => (value ?? '').toString();
  String _id(Map<String, dynamic> row) => _s(row['id']);
  String _status(Map<String, dynamic> row) => _s(row['consent_status']);
  int get _consented => _rows.where((r) => _status(r) == 'consented').length;

  List<Map<String, dynamic>> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _rows.where((row) {
      final status = _status(row);
      final statusOk = _filter == 'الكل' ||
          (_filter == 'موافق' && status == 'consented') ||
          (_filter == 'بانتظار الموافقة' && status == 'pending') ||
          (_filter == 'غير موافق' && status == 'declined');
      final text = [_s(row['contact_name']), _s(row['phone']), _s(row['group_name'])].join(' ').toLowerCase();
      return statusOk && (query.isEmpty || text.contains(query));
    }).toList();
  }

  Future<void> _load() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة أولًا.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    try {
      final rows = await _repo.fetchContacts(_company.text.trim());
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _selected.removeWhere((id) => !rows.any((r) => _id(r) == id));
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل سجل جهات الاتصال: ' + e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _task(String label, IconData icon, Color color, VoidCallback? action) =>
      ErpQuickTaskButton(label: label, icon: icon, onPressed: action, fallbackColor: color);

  Future<void> _openWhatsApp() async {
    try {
      final opened = await launchUrl(Uri.parse('https://web.whatsapp.com/'), mode: LaunchMode.externalApplication);
      if (mounted) setState(() {
        if (opened) {
          _message = 'تم فتح واتساب ويب خارجيًا. لا تتم مشاركة بيانات الدخول مع سلسلة.';
        } else {
          _error = 'تعذر فتح واتساب ويب على هذا الجهاز.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح واتساب ويب: ' + e.toString());
    }
  }

  List<List<String>> _csvMatrix(String content) {
    final result = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (ch == '"') {
        if (quoted && i + 1 < content.length && content[i + 1] == '"') {
          cell.write('"'); i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == ',' && !quoted) {
        row.add(cell.toString().trim()); cell.clear();
      } else if ((ch == '\n' || ch == '\r') && !quoted) {
        if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') i++;
        row.add(cell.toString().trim()); cell.clear();
        if (row.any((v) => v.isNotEmpty)) result.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
    row.add(cell.toString().trim());
    if (row.any((v) => v.isNotEmpty)) result.add(row);
    return result;
  }

  List<Map<String, String>> _parseCsv(String content) {
    final matrix = _csvMatrix(content);
    if (matrix.length < 2) return [];
    final headers = matrix.first.map((v) => v.toLowerCase().trim()).toList();
    int col(List<String> names) => headers.indexWhere(names.contains);
    final phoneCol = col(['رقم الموبايل','رقم الهاتف','الموبايل','الهاتف','phone','mobile','phone number','whatsapp']);
    final nameCol = col(['اسم الحساب أو المستخدم','اسم المستخدم','الاسم','name','contact name','username','account name']);
    final groupCol = col(['اسم الجروب','الجروب','المجموعة','group','group name']);
    if (phoneCol < 0) throw const FormatException('يجب وجود عمود رقم الموبايل أو phone في ملف CSV.');
    String at(List<String> row, int index) => index >= 0 && index < row.length ? row[index] : '';
    return matrix.skip(1).where((row) => at(row, phoneCol).trim().isNotEmpty).map((row) => {
      'name': at(row, nameCol),
      'phone': at(row, phoneCol),
      'group': at(row, groupCol).isEmpty ? _source.text.trim() : at(row, groupCol),
      'source': 'csv',
    }).toList();
  }

  List<Map<String, String>> _parseVCard(String content) {
    final cards = content.replaceAll('\r\n ', '').replaceAll('\n ', '')
        .split(RegExp(r'BEGIN:VCARD', caseSensitive: false));
    final result = <Map<String, String>>[];
    for (final card in cards) {
      if (!card.toUpperCase().contains('END:VCARD')) continue;
      var name = '', phone = '';
      for (final line in card.split(RegExp(r'\r?\n'))) {
        final separator = line.indexOf(':');
        if (separator < 0) continue;
        final key = line.substring(0, separator).toUpperCase();
        final value = line.substring(separator + 1).trim();
        if (key.startsWith('FN')) name = value;
        if (key.startsWith('TEL') && phone.isEmpty) phone = value;
      }
      phone = ErpWhatsappContactsRepository.normalizePhone(phone);
      if (phone.replaceAll('+', '').length >= 7) {
        result.add({'name': name, 'phone': phone, 'group': _source.text.trim(), 'source': 'vcard'});
      }
    }
    return result;
  }

  Future<void> _importFile() async {
    if (_company.text.trim().isEmpty) {
      setState(() => _error = 'أدخل معرّف الشركة قبل الاستيراد.');
      return;
    }
    setState(() { _saving = true; _error = null; _message = null; });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv','vcf','vcard'], withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) throw StateError('الملف فارغ أو تعذرت قراءته.');
      final content = utf8.decode(file.bytes!, allowMalformed: true);
      final ext = (file.extension ?? '').toLowerCase();
      final parsed = (ext == 'vcf' || ext == 'vcard') ? _parseVCard(content) : _parseCsv(content);
      final unique = <String, Map<String, String>>{};
      for (final item in parsed) {
        final phone = ErpWhatsappContactsRepository.normalizePhone(item['phone'] ?? '');
        if (phone.replaceAll('+', '').length < 7) continue;
        unique.putIfAbsent(phone, () => {
          'name': (item['name'] ?? '').trim(),
          'phone': item['phone']!.trim(),
          'group': (item['group'] ?? _source.text).trim(),
          'source': (ext == 'vcf' || ext == 'vcard') ? 'vcard' : 'csv',
        });
      }
      if (unique.isEmpty) throw const FormatException('لم نعثر على أرقام صالحة. استخدم CSV أو VCF.');
      final batchId = await _repo.createBatch(
        companyId: _company.text.trim(),
        sourceLabel: _source.text.trim().isEmpty ? 'استيراد ملف' : _source.text.trim(),
        fileName: file.name,
        sourceType: (ext == 'vcf' || ext == 'vcard') ? 'vcard' : 'csv',
        totalContacts: unique.length,
      );
      await _repo.insertContacts(companyId: _company.text.trim(), batchId: batchId, contacts: unique.values.toList());
      await _load();
      if (mounted) setState(() => _message = 'تم استيراد ' + unique.length.toString() + ' سجلًا. جميع السجلات بانتظار توثيق الموافقة.');
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل الاستيراد: ' + e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _consent() async {
    final ids = _selected.where((id) => _rows.any((r) => _id(r) == id && _status(r) != 'consented')).toList();
    if (ids.isEmpty) { setState(() => _message = 'حدد سجلات لم يتم توثيق موافقتها بعد.'); return; }
    final evidence = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var checked = false;
        return StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
          title: const Text('توثيق موافقة جهات الاتصال'),
          content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('سيتم توثيق موافقة ' + ids.length.toString() + ' جهة اتصال. لا تستخدم الإجراء إلا بعد الحصول على موافقة أصحاب الأرقام.'),
            const SizedBox(height: 10),
            TextField(controller: evidence, decoration: const InputDecoration(labelText: 'مرجع الموافقة / ملاحظات (اختياري)', border: OutlineInputBorder())),
            CheckboxTheme(
              data: const CheckboxThemeData(shape: CircleBorder()),
              child: CheckboxListTile(
                value: checked, contentPadding: EdgeInsets.zero,
                title: const Text('أؤكد الحصول على الموافقة المناسبة.'),
                onChanged: (v) => refresh(() => checked = v ?? false),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: checked ? () => Navigator.pop(ctx, true) : null, child: const Text('توثيق')),
          ],
        ));
      },
    );
    if (accepted != true) { evidence.dispose(); return; }
    try {
      setState(() => _saving = true);
      await _repo.markConsented(ids, evidence: evidence.text);
      await _load();
      if (mounted) setState(() => _message = 'تم توثيق الموافقة للسجلات المحددة.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر توثيق الموافقة: ' + e.toString());
    } finally {
      evidence.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _decline() async {
    if (_selected.isEmpty) return;
    try {
      setState(() => _saving = true);
      await _repo.markDeclined(_selected.toList());
      await _load();
      if (mounted) setState(() => _message = 'تم تحديث حالة السجلات المحددة.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحديث الحالة: ' + e.toString());
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _delete() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف السجلات المحددة'),
      content: Text('حذف ' + ids.length.toString() + ' سجل نهائيًا؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (confirmed != true) return;
    try {
      setState(() => _saving = true);
      await _repo.deleteContacts(ids);
      _selected.clear();
      await _load();
      if (mounted) setState(() => _message = 'تم حذف السجلات المحددة.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر الحذف: ' + e.toString());
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _export() async {
    final records = _selected.isEmpty
        ? _rows.where((r) => _status(r) == 'consented').toList()
        : _rows.where((r) => _selected.contains(_id(r)) && _status(r) == 'consented').toList();
    if (records.isEmpty) {
      setState(() => _message = 'لا توجد سجلات محددة موثقة الموافقة للتصدير.');
      return;
    }
    try {
      setState(() { _saving = true; _error = null; _message = null; });
      final book = excel.Excel.createExcel();
      final sheet = book['جهات اتصال واتساب'];
      sheet.appendRow([
        excel.TextCellValue('م'),
        excel.TextCellValue('رقم موبايل'),
        excel.TextCellValue('اسم الحساب أو المستخدم'),
        excel.TextCellValue('اسم الجروب'),
      ]);
      for (var i = 0; i < records.length; i++) {
        final row = records[i];
        sheet.appendRow([
          excel.IntCellValue(i + 1),
          excel.TextCellValue(_s(row['phone'])),
          excel.TextCellValue(_s(row['contact_name'])),
          excel.TextCellValue(_s(row['group_name'])),
        ]);
      }
      final bytes = book.encode();
      if (bytes == null || bytes.isEmpty) throw StateError('تعذر إنشاء ملف Excel.');
      await FileSaver.instance.saveFile(
        name: 'silsila_whatsapp_contacts_' + DateTime.now().millisecondsSinceEpoch.toString(),
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) setState(() => _message = 'تم تصدير ' + records.length.toString() + ' جهة اتصال إلى Excel.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تصدير Excel: ' + e.toString());
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _save() async {
    await _load();
    if (mounted) setState(() => _message = 'تم تحديث البيانات المحفوظة من قاعدة البيانات.');
  }

  Future<void> _edit() async {
    if (_selected.length != 1) {
      setState(() => _message = 'حدد جهة اتصال واحدة فقط للتعديل.');
      return;
    }
    final id = _selected.first;
    final row = _rows.firstWhere((item) => _id(item) == id);
    final name = TextEditingController(text: _s(row['contact_name']));
    final phone = TextEditingController(text: _s(row['phone']));
    final group = TextEditingController(text: _s(row['group_name']));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل جهة اتصال'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الحساب أو المستخدم')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الموبايل')),
          TextField(controller: group, decoration: const InputDecoration(labelText: 'اسم الجروب / المصدر')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ التعديل')),
        ],
      ),
    );
    if (accepted != true) { name.dispose(); phone.dispose(); group.dispose(); return; }
    try {
      setState(() => _saving = true);
      await _repo.updateContact(id: id, contactName: name.text, phone: phone.text, groupName: group.text);
      await _load();
      if (mounted) setState(() => _message = 'تم تعديل جهة الاتصال.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تعديل جهة الاتصال: ' + e.toString());
    } finally {
      name.dispose(); phone.dispose(); group.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _preview() async {
    final rows = _selected.isEmpty ? _visible : _rows.where((r) => _selected.contains(_id(r))).toList();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('معاينة جهات الاتصال (' + rows.length.toString() + ')'),
        content: SizedBox(width: 560, height: 420, child: rows.isEmpty
          ? const Center(child: Text('لا توجد سجلات للمعاينة.'))
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final row = rows[i];
                return ListTile(
                  title: Text(_s(row['contact_name']).isEmpty ? 'اسم غير مسجل' : _s(row['contact_name'])),
                  subtitle: Text(_s(row['phone']) + ' • ' + _s(row['group_name']) + ' • ' + (_status(row) == 'consented' ? 'موافق' : _status(row) == 'declined' ? 'غير موافق' : 'بانتظار الموافقة')),
                );
              },
            )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<Uint8List> _pdfBytes() async {
    final candidates = _selected.isEmpty ? _visible : _rows.where((r) => _selected.contains(_id(r))).toList();
    final rows = candidates.where((r) => _status(r) == 'consented').toList();
    if (rows.isEmpty) throw StateError('لا توجد سجلات موثقة الموافقة للطباعة أو PDF.');
    final reportDate = DateTime.now();
    final dateLabel = reportDate.day.toString().padLeft(2, '0') + '-' + reportDate.month.toString().padLeft(2, '0') + '-' + reportDate.year.toString();
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal.ttf'));
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(22),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
        pw.Text('سلسلة — جهات اتصال واتساب', textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('عدد السجلات: ' + rows.length.toString() + '    •    تاريخ التقرير: ' + dateLabel,
          textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['اسم الجروب', 'اسم الحساب أو المستخدم', 'رقم موبايل', 'م'],
          data: rows.asMap().entries.map((entry) {
            final row = entry.value;
            return [_s(row['group_name']), _s(row['contact_name']), _s(row['phone']), (entry.key + 1).toString()];
          }).toList(),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
        ),
      ],
    ));
    return Uint8List.fromList(await pdf.save());
  }

  Future<void> _print() async {
    try {
      setState(() => _saving = true);
      final bytes = await _pdfBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'silsila_whatsapp_contacts.pdf');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذرت الطباعة: ' + e.toString());
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _exportPdf() async {
    try {
      setState(() => _saving = true);
      final bytes = await _pdfBytes();
      await FileSaver.instance.saveFile(
        name: 'silsila_whatsapp_contacts_' + DateTime.now().millisecondsSinceEpoch.toString(),
        bytes: bytes, fileExtension: 'pdf', mimeType: MimeType.pdf,
      );
      if (mounted) setState(() => _message = 'تم تصدير ملف PDF.');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تصدير PDF: ' + e.toString());
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _stat(String title, int value, IconData icon, Color color) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(11), child: Row(children: [
      CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 11)),
        Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ])),
    ]))),
  );

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(color: purple, child: Padding(padding: const EdgeInsets.all(11), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('سحب أرقام جروبات واتساب', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const Text('استيراد جهات الاتصال المصرح بها • المراجعة • التوثيق • Excel', style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 7),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _task('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
              _task('إضافة', Icons.person_add_alt_1, Colors.green, _saving ? null : _importFile),
              _task('حفظ', Icons.save_outlined, Colors.green, _saving ? null : _save),
              _task('تعديل', Icons.edit_outlined, orange, _saving ? null : _edit),
              _task('حذف', Icons.delete_outline, Colors.red, _saving ? null : _delete),
              _task('معاينة', Icons.visibility_outlined, const Color(0xFF7040A0), _preview),
              _task('طباعة', Icons.print_outlined, Colors.blueGrey, _saving ? null : _print),
              _task('Excel', Icons.table_view_outlined, Colors.green, _saving ? null : _export),
              _task('PDF', Icons.picture_as_pdf_outlined, Colors.red, _saving ? null : _exportPdf),
            ])),
          ],
        ))),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.qr_code_2, color: purple, size: 27),
              const SizedBox(width: 8),
              const Expanded(child: Text('حساب واتساب', style: TextStyle(fontWeight: FontWeight.w900))),
              const Chip(label: Text('غير مربوط داخل النظام')),
            ]),
            const Text('يفتح واتساب ويب في نافذة مستقلة. لا تحفظ سلسلة كلمة المرور أو رمز QR أو جلسة واتساب، ولا تستخرج أعضاء الجروبات تلقائيًا.'),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح واتساب ويب'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF168447)),
            )),
          ],
        ))),
        Card(child: Padding(padding: const EdgeInsets.all(11), child: Wrap(
          spacing: 9, runSpacing: 9, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 250, child: TextField(controller: _company, decoration: const InputDecoration(labelText: 'معرّف الشركة (UUID)', border: OutlineInputBorder(), isDense: true))),
            SizedBox(width: 230, child: TextField(controller: _source, decoration: const InputDecoration(labelText: 'اسم الجروب / مصدر القائمة', border: OutlineInputBorder(), isDense: true))),
            FilledButton.icon(onPressed: _saving ? null : _importFile, icon: const Icon(Icons.upload_file), label: const Text('استيراد CSV / VCF')),
          ],
        ))),
        if (_error != null) _notice(_error!, Colors.red),
        if (_message != null) _notice(_message!, Colors.green),
        if (_loading || _saving) const LinearProgressIndicator(),
        Row(children: [
          _stat('إجمالي السجلات', _rows.length, Icons.contacts, purple),
          _stat('موافقة موثقة', _consented, Icons.verified_user, Colors.green),
          _stat('محددة', _selected.length, Icons.checklist, orange),
        ]),
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 230, child: TextField(controller: _search, onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم أو الرقم أو الجروب', border: OutlineInputBorder(), isDense: true))),
            SizedBox(width: 180, child: DropdownButtonFormField<String>(
              value: _filter, decoration: const InputDecoration(labelText: 'حالة الموافقة', border: OutlineInputBorder(), isDense: true),
              items: const ['الكل','موافق','بانتظار الموافقة','غير موافق'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _filter = v ?? 'الكل'),
            )),
            OutlinedButton.icon(onPressed: visible.isEmpty ? null : () => setState(() {
              final ids = visible.map(_id).toSet();
              if (ids.every(_selected.contains)) { _selected.removeAll(ids); } else { _selected.addAll(ids); }
            }), icon: const Icon(Icons.select_all), label: const Text('تحديد الظاهر')),
            FilledButton.icon(onPressed: _saving || _selected.isEmpty ? null : _consent, icon: const Icon(Icons.verified_user), label: const Text('توثيق الموافقة')),
            OutlinedButton.icon(onPressed: _saving || _selected.isEmpty ? null : _decline, icon: const Icon(Icons.block), label: const Text('غير موافق')),
          ]),
          const SizedBox(height: 8),
          SizedBox(height: 390, child: visible.isEmpty
            ? const Center(child: Text('لا توجد جهات اتصال مطابقة. استورد ملف CSV أو VCF للبدء.'))
            : ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = visible[index];
                final id = _id(row);
                final status = _status(row);
                final statusText = status == 'consented' ? 'موافق' : status == 'declined' ? 'غير موافق' : 'بانتظار الموافقة';
                return CheckboxTheme(
                  data: const CheckboxThemeData(shape: CircleBorder()),
                  child: CheckboxListTile(
                    value: _selected.contains(id),
                    onChanged: (v) => setState(() { if (v == true) { _selected.add(id); } else { _selected.remove(id); } }),
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: const CircleAvatar(backgroundColor: Color(0xFFF5EFFB), child: Icon(Icons.person, color: purple)),
                    title: Text(_s(row['contact_name']).isEmpty ? 'اسم غير مسجل' : _s(row['contact_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_s(row['phone']) + ' • ' + (_s(row['group_name']).isEmpty ? 'مصدر غير محدد' : _s(row['group_name'])) + ' • ' + statusText),
                    activeColor: purple,
                  ),
                );
              },
            )),
          Align(alignment: Alignment.centerRight, child: Text(visible.length.toString() + ' سجل ظاهر • التصدير للسجلات الموثقة بالموافقة فقط', style: const TextStyle(fontSize: 11, color: Colors.black54))),
        ]))),
        const Text('تنبيه: هذا الإصدار لا يقرأ واجهة واتساب ولا يستخرج أعضاء المجموعات. أي ربط رسمي لاحق يتطلب تطبيق Meta وصلاحيات API معتمدة للحساب.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    ));
  }

  Widget _notice(String text, Color color) => Container(
    margin: const EdgeInsets.symmetric(vertical: 5),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(9)),
    child: Text(text, style: TextStyle(color: color)),
  );
}
