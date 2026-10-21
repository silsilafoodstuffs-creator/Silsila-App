import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/erp_workspace_records_service.dart';

class ErpActivityTypesScreen extends StatefulWidget {
  const ErpActivityTypesScreen({super.key, this.companyId});
  final String? companyId;
  @override
  State<ErpActivityTypesScreen> createState() => _ErpActivityTypesScreenState();
}

class _ErpActivityTypesScreenState extends State<ErpActivityTypesScreen> {
  final _service = ErpWorkspaceRecordsService();
  final _picker = ImagePicker();
  final _code = TextEditingController();
  final _ar = TextEditingController();
  final _en = TextEditingController();
  final List<Map<String, String>> _rows = [];
  String? _selected;
  String? _editing;
  String? _image;
  bool _active = true, _loading = false, _saving = false;
  String? _message;
  String? _resolvedCompanyId;
  String? get _companyId => (widget.companyId?.trim().isNotEmpty == true) ? widget.companyId!.trim() : _resolvedCompanyId;
  static const _pageKey = 'أنواع الأنشطة';

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant ErpActivityTypesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _load();
  }
  @override
  void dispose() { _code.dispose(); _ar.dispose(); _en.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _message = null; });
    try {
      // The dashboard resolves its company asynchronously. Resolve it here too,
      // and reject a stale company ID that is not one of this user's active memberships.
      String? companyId = _companyId;
      final db = Supabase.instance.client;
      final userId = db.auth.currentUser?.id;
      if (userId != null) {
        final memberships = await db
            .from('erp_company_members')
            .select('company_id')
            .eq('user_id', userId)
            .eq('is_active', true)
            .order('created_at');
        final ids = (memberships as List)
            .map((row) => (row['company_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
        if (ids.isNotEmpty && (companyId == null || !ids.contains(companyId))) {
          companyId = ids.first;
        }
      }
      if (companyId == null || companyId.trim().isEmpty) {
        if (mounted) setState(() => _message = userId == null
            ? 'سجّل الدخول إلى النظام لعرض أنواع الأنشطة وحفظها.'
            : 'لا توجد شركة نشطة مرتبطة بالمستخدم الحالي.');
        return;
      }
      _resolvedCompanyId = companyId;
      final data = await _service.listPage(companyId: companyId, pageKey: _pageKey);
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(data)
          ..sort((a, b) => (int.tryParse(a['ترتيب السطر'] ?? '') ?? 0)
              .compareTo(int.tryParse(b['ترتيب السطر'] ?? '') ?? 0));
        _message = data.isEmpty ? 'لا توجد أنواع أنشطة محفوظة بعد؛ يمكنك إضافة أول نشاط.' : 'تم تحديث أنواع الأنشطة.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تحميل الأنشطة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _new() { setState(() { _editing = null; _selected = null; _code.clear(); _ar.clear(); _en.clear(); _image = null; _active = true; _message = 'أدخل بيانات النشاط ثم اضغط حفظ.'; }); }
  void _edit(Map<String,String> r) { setState(() { _editing = r['_مرجع داخلي']; _selected = r['كود النشاط']; _code.text = r['كود النشاط'] ?? ''; _ar.text = r['اسم النشاط عربي'] ?? ''; _en.text = r['اسم النشاط إنجليزي'] ?? ''; _image = r['صورة النشاط']; _active = (r['نشط'] ?? 'true') == 'true'; }); }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 75, maxWidth: 800);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() { _image = 'data:image/jpeg;base64,' + base64Encode(bytes); _message = 'تم اختيار صورة النشاط.'; });
    } catch (e) { if (mounted) setState(() => _message = 'تعذر فتح الكاميرا أو الصور: ' + e.toString()); }
  }

  Future<void> _save() async {
    final code = _code.text.trim(), ar = _ar.text.trim();
    if ((_companyId ?? '').isEmpty) { setState(() => _message = 'لا توجد شركة نشطة للحفظ.'); return; }
    if (code.isEmpty || ar.isEmpty) { setState(() => _message = 'كود النشاط والاسم العربي مطلوبان.'); return; }
    if (_rows.any((r) => r['كود النشاط'] == code && r['_مرجع داخلي'] != _editing)) { setState(() => _message = 'كود النشاط مستخدم بالفعل.'); return; }
    setState(() => _saving = true);
    try {
      final old = _rows.where((r) => r['_مرجع داخلي'] == _editing).firstOrNull;
      final row = <String,String>{'ترتيب السطر': old?['ترتيب السطر'] ?? (_rows.length + 1).toString(), 'كود النشاط': code, 'اسم النشاط عربي': ar, 'اسم النشاط إنجليزي': _en.text.trim(), 'صورة النشاط': _image ?? '', 'نشط': _active.toString()};
      if ((_editing ?? '').isNotEmpty) row['_مرجع داخلي'] = _editing!;
      await _service.saveRecord(companyId: _companyId!, pageKey: _pageKey, record: row);
      await _load();
      if (mounted) setState(() => _message = 'تم حفظ النشاط في قاعدة البيانات.');
    } catch (e) { if (mounted) setState(() => _message = 'تعذر الحفظ: ' + e.toString()); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _delete() async {
    final row = _rows.where((r) => r['كود النشاط'] == _selected).firstOrNull;
    if (row == null) { setState(() => _message = 'حدد النشاط المطلوب حذفه أولاً.'); return; }
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('تأكيد الحذف'), content: Text('حذف النشاط: ' + (row['اسم النشاط عربي'] ?? '')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('نعم، حذف'))]));
    if (yes != true) return;
    try { await _service.deleteRecord(companyId: _companyId!, pageKey: _pageKey, recordKey: row['_مرجع داخلي'] ?? row['كود النشاط']!); await _load(); _new(); }
    catch (e) { if (mounted) setState(() => _message = 'تعذر الحذف: ' + e.toString()); }
  }

  Widget _task(String text, IconData icon, Color color, VoidCallback? action) => Padding(padding: const EdgeInsetsDirectional.only(end: 5), child: FilledButton.tonalIcon(onPressed: action, style: FilledButton.styleFrom(foregroundColor: color, backgroundColor: color.withValues(alpha: .10), visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8)), icon: Icon(icon, size: 16), label: Text(text, style: const TextStyle(fontSize: 12))));
  Widget _field(String label, TextEditingController c, double width) => SizedBox(width: width, child: TextField(controller: c, style: const TextStyle(fontSize: 12), decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9), border: const OutlineInputBorder())));

  Future<void> _preview() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('معاينة أنواع الأنشطة'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _rows.map((r) => ListTile(
                dense: true,
                title: Text('${r['كود النشاط'] ?? ''} — ${r['اسم النشاط عربي'] ?? ''}'),
                subtitle: Text(r['اسم النشاط إنجليزي'] ?? ''),
              )).toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: const BoxDecoration(color: Color(0xFF3E007D), borderRadius: BorderRadius.vertical(top: Radius.circular(10))), child: const Row(children: [Icon(Icons.category_outlined, color: Colors.white), SizedBox(width: 8), Text('أنواع الأنشطة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Spacer(), Text('إدارة البرنامج • بيانات أساسية', style: TextStyle(color: Colors.white70, fontSize: 11))])),
      Container(color: Colors.white, padding: const EdgeInsets.all(8), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _task('تحديث', Icons.refresh, Colors.blue, _loading ? null : _load),
        _task('إضافة', Icons.add_circle_outline, Colors.green, _new),
        _task('حفظ', Icons.save_outlined, const Color(0xFF3E007D), _saving ? null : _save),
        _task('تعديل', Icons.edit_outlined, Colors.orange, _selected == null ? null : () { final r = _rows.where((x) => x['كود النشاط'] == _selected).firstOrNull; if (r != null) _edit(r); }),
        _task('حذف', Icons.delete_outline, Colors.red, _delete),
        _task('معاينة', Icons.visibility_outlined, Colors.teal, _preview),
        _task('طباعة', Icons.print_outlined, Colors.blueGrey, () => setState(() => _message = 'تم تجهيز معاينة الطباعة؛ استخدم نافذة المعاينة.')),
        _task('استيراد Excel', Icons.file_upload_outlined, Colors.green.shade800, () => setState(() => _message = 'استيراد Excel لم يُفعّل في هذه الشاشة بعد.')),
        _task('طباعة PDF', Icons.picture_as_pdf_outlined, Colors.red, () => setState(() => _message = 'تصدير PDF لم يُفعّل في هذه الشاشة بعد.')),
      ]))),
      if (_message != null) Container(color: const Color(0xFFF7F2FC), padding: const EdgeInsets.all(7), child: Text(_message!, style: const TextStyle(fontSize: 11, color: Color(0xFF3E007D)))),
      Container(color: Colors.white, padding: const EdgeInsets.all(9), child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _field('كود النشاط', _code, 120), _field('اسم النشاط عربي', _ar, 200), _field('اسم النشاط إنجليزي', _en, 180),
        OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined, size: 17), label: const Text('استيراد صورة')),
        OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined, size: 17), label: const Text('تصوير')),
        if ((_image ?? '').startsWith('data:image')) ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.memory(base64Decode(_image!.split(',').last), width: 38, height: 32, fit: BoxFit.cover)),
        Row(mainAxisSize: MainAxisSize.min, children: [const Text('نشط', style: TextStyle(fontSize: 12)), Switch.adaptive(value: _active, onChanged: (v) => setState(() => _active = v))]),
      ])),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE4DDED)), borderRadius: BorderRadius.circular(8)), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowHeight: 34, dataRowMinHeight: 38, dataRowMaxHeight: 42, horizontalMargin: 8, columnSpacing: 14, headingRowColor: WidgetStateProperty.all(const Color(0xFFF1EAF9)), columns: const [DataColumn(label: Text('م')), DataColumn(label: Text('كود النشاط')), DataColumn(label: Text('اسم النشاط عربي')), DataColumn(label: Text('اسم النشاط إنجليزي')), DataColumn(label: Text('صورة النشاط')), DataColumn(label: Text('نشط'))], rows: [
        for (var i = 0; i < _rows.length; i++) DataRow(selected: _rows[i]['كود النشاط'] == _selected, onSelectChanged: (_) { setState(() => _selected = _rows[i]['كود النشاط']); _edit(_rows[i]); }, cells: [
          DataCell(SizedBox(width: 24, child: Text(_rows[i]['ترتيب السطر'] ?? (i + 1).toString(), style: const TextStyle(fontSize: 12)))),
          DataCell(SizedBox(width: 100, child: Text(_rows[i]['كود النشاط'] ?? '', style: const TextStyle(fontSize: 12)))),
          DataCell(SizedBox(width: 180, child: Text(_rows[i]['اسم النشاط عربي'] ?? '', style: const TextStyle(fontSize: 12)))),
          DataCell(SizedBox(width: 170, child: Text(_rows[i]['اسم النشاط إنجليزي'] ?? '', style: const TextStyle(fontSize: 12)))),
          DataCell(SizedBox(width: 70, child: Row(children: [if ((_rows[i]['صورة النشاط'] ?? '').startsWith('data:image')) Image.memory(base64Decode(_rows[i]['صورة النشاط']!.split(',').last), width: 30, height: 28, fit: BoxFit.cover) else const Icon(Icons.image_outlined, size: 20), IconButton(tooltip: 'استيراد أو تصوير', visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_a_photo_outlined, size: 16), onPressed: () { _edit(_rows[i]); showModalBottomSheet<void>(context: context, builder: (c) => SafeArea(child: Wrap(children: [ListTile(title: const Text('استيراد صورة'), leading: const Icon(Icons.photo_library), onTap: () { Navigator.pop(c); _pick(ImageSource.gallery); }), ListTile(title: const Text('التصوير بالكاميرا'), leading: const Icon(Icons.camera_alt), onTap: () { Navigator.pop(c); _pick(ImageSource.camera); })]))); })]))),
          DataCell(Checkbox(value: (_rows[i]['نشط'] ?? 'true') == 'true', visualDensity: VisualDensity.compact, onChanged: (v) async { final row = Map<String,String>.from(_rows[i])..['نشط'] = (v ?? false).toString(); try { await _service.saveRecord(companyId: _companyId!, pageKey: _pageKey, record: row); await _load(); } catch (e) { if (mounted) setState(() => _message = 'تعذر تحديث الحالة: ' + e.toString()); } })),
        ]),
      ]))),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
      if (_rows.isEmpty && !_loading) const Padding(padding: EdgeInsets.all(18), child: Text('لا توجد أنواع أنشطة محفوظة بعد. استخدم «إضافة» لإدخال أول نشاط.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
    ]));
  }
}
