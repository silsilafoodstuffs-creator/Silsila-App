import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/erp_studio_draft_store.dart';
import '../services/erp_studio_repository.dart';
import '../services/studio_document.dart';
import '../services/studio_renderer.dart';

const _studioPurple = Color(0xFF3E007D);
const _studioOrange = Color(0xFFFFA015);

class SilsilaStudioScreen extends StatefulWidget {
  const SilsilaStudioScreen({super.key, this.companyId});
  final String? companyId;
  @override State<SilsilaStudioScreen> createState() => _SilsilaStudioScreenState();
}

class _SilsilaStudioScreenState extends State<SilsilaStudioScreen> {
  final _store = StudioDraftStore();
  final _repository = ErpStudioRepository();
  StudioDocument _doc = StudioDocument.create('شاشة جديدة');
  String? _selectedId;
  bool _preview = false;
  bool _busy = false;
  final List<StudioDocument> _undo = [];
  final List<StudioDocument> _redo = [];

  StudioNode? get _selected {
    for (final node in _doc.nodes) {
      if (node.id == _selectedId) return node;
    }
    return null;
  }

  void _change(StudioDocument next) {
    _undo.add(_doc);
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
    setState(() => _doc = next);
  }

  void _add(String type) {
    final id = '${type}_${DateTime.now().microsecondsSinceEpoch}';
    final defaults = <String, Map<String, dynamic>>{
      'text': {'text': 'نص جديد', 'size': 14},
      'button': {'text': 'زر جديد'},
      'field': {'label': 'اسم الحقل', 'hint': 'أدخل القيمة'},
      'card': {'title': 'بطاقة جديدة', 'subtitle': 'وصف البطاقة'},
      'divider': {},
      'spacer': {'height': 10},
      'grid': {'columns': 2},
      'tree': {},
      'table': {},
    };
    final nodes = [..._doc.nodes, StudioNode(id: id, type: type, props: defaults[type]!)];
    _change(_doc.copyWith(nodes: nodes));
    setState(() => _selectedId = id);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await _store.save(_doc);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المسودة محلياً.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _saveCloud() async {
    final company = widget.companyId;
    if (company == null || company.trim().isEmpty) {
      _notice('يجب اختيار شركة نشطة قبل الحفظ المركزي.');
      return;
    }
    setState(() => _busy = true);
    try {
      final remoteId = await _repository.saveDraft(
        companyId: company,
        document: _doc,
        designKey: 'studio_${_doc.id}',
        remoteId: _doc.remoteId,
        expectedRevision: _doc.remoteRevision == 0 ? null : _doc.remoteRevision,
      );
      _doc = _doc.copyWith(remoteId: remoteId, remoteRevision: _doc.remoteRevision + 1);
      await _store.save(_doc);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ التصميم مركزياً — الإصدار ${_doc.remoteRevision}.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ المركزي: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCloud() async {
    final company = widget.companyId;
    if (company == null || company.trim().isEmpty) {
      _notice('يجب اختيار شركة نشطة لعرض التصميمات السحابية.');
      return;
    }
    setState(() => _busy = true);
    try {
      final designs = await _repository.listDesigns(company);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('التصميمات السحابية'),
        content: SizedBox(width: 560, child: designs.isEmpty
          ? const Text('لا توجد تصميمات سحابية لهذه الشركة.')
          : ListView(shrinkWrap: true, children: designs.map((row) => ListTile(
              title: Text((row['name'] ?? 'تصميم').toString()),
              subtitle: Text('الإصدار ${row['revision']} • ${row['status']} • ${row['design_kind']}'),
              onTap: () async {
                Navigator.pop(dialogContext);
                try {
                  final remote = await _repository.getDesign(companyId: company, designId: row['id'].toString());
                  final raw = remote['design_json'];
                  if (raw is! Map) throw const FormatException('محتوى التصميم السحابي غير صالح.');
                  final loaded = StudioDocument.fromJson(Map<String, dynamic>.from(raw));
                  if (!mounted) return;
                  setState(() {
                    _doc = loaded.copyWith(remoteId: remote['id'].toString(), remoteRevision: remote['revision'] as int? ?? 0);
                    _selectedId = null;
                    _preview = false;
                  });
                } catch (e) {
                  if (mounted) _notice('تعذر فتح التصميم السحابي: $e');
                }
              },
              trailing: IconButton(
                tooltip: 'سجل الإصدارات',
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showVersions(row['id'].toString());
                },
              ),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ));
    } catch (e) {
      if (mounted) _notice('تعذر تحميل التصميمات السحابية: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showVersions(String designId) async {
    final company = widget.companyId;
    if (company == null) return;
    try {
      final versions = await _repository.listVersions(companyId: company, designId: designId);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('سجل إصدارات التصميم'),
        content: SizedBox(width: 560, child: versions.isEmpty
          ? const Text('لا توجد إصدارات مسجلة.')
          : ListView(shrinkWrap: true, children: versions.map((version) => ListTile(
              title: Text('الإصدار ${version['revision']}'),
              subtitle: Text((version['change_note'] ?? '').toString()),
              trailing: IconButton(
                tooltip: 'استعادة هذا الإصدار كمسودة جديدة',
                icon: const Icon(Icons.restore),
                onPressed: _busy ? null : () async {
                  Navigator.pop(dialogContext);
                  try {
                    final current = await _repository.getDesign(companyId: company, designId: designId);
                    final nextRevision = await _repository.restoreVersion(
                      companyId: company,
                      designId: designId,
                      targetRevision: version['revision'] as int,
                      expectedRevision: current['revision'] as int,
                    );
                    final restored = StudioDocument.fromJson(Map<String, dynamic>.from(version['design_json'] as Map));
                    if (!mounted) return;
                    setState(() {
                      _doc = restored.copyWith(remoteId: designId, remoteRevision: nextRevision);
                      _selectedId = null;
                      _preview = false;
                    });
                    _notice('تمت الاستعادة كمسودة جديدة بالإصدار $nextRevision.');
                  } catch (e) {
                    if (mounted) _notice('تعذرت استعادة الإصدار: $e');
                  }
                },
              ),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ));
    } catch (e) {
      if (mounted) _notice('تعذر تحميل سجل الإصدارات: $e');
    }
  }

  Future<void> _approveCurrent() async {
    final company = widget.companyId;
    if (company == null || _doc.remoteId == null) { _notice('احفظ التصميم سحابياً أولاً.'); return; }
    try {
      await _repository.approve(companyId: company, designId: _doc.remoteId!, expectedRevision: _doc.remoteRevision);
      _notice('تم اعتماد الإصدار الحالي.');
    } catch (e) { _notice('تعذر اعتماد التصميم: $e'); }
  }

  Future<void> _publishCurrent() async {
    final company = widget.companyId;
    if (company == null || _doc.remoteId == null) { _notice('احفظ التصميم سحابياً أولاً.'); return; }
    try {
      await _repository.publish(companyId: company, designId: _doc.remoteId!, testedRevision: _doc.remoteRevision);
      _notice('تم نشر الإصدار المعتمد.');
    } catch (e) { _notice('تعذر نشر التصميم: $e'); }
  }

  Future<void> _open() async {
    final drafts = await _store.list();
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('التصميمات المحفوظة'),
      content: SizedBox(width: 420, child: drafts.isEmpty
        ? const Text('لا توجد مسودات محفوظة.')
        : ListView(shrinkWrap: true, children: drafts.map((d) => ListTile(
            title: Text(d.name),
            subtitle: Text('${d.nodes.length} مكون'),
            onTap: () { setState(() { _doc = d; _selectedId = null; }); Navigator.pop(context); },
          )).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    ));
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: _doc.encode()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ JSON التصميم إلى الحافظة.')));
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('استيراد تصميم JSON'),
      content: SizedBox(width: 500, child: TextField(
        controller: controller, minLines: 5, maxLines: 12,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'الصق تعريف JSON هنا'),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تحقق واستيراد')),
      ],
    ));
    if (accepted != true) return;
    try {
      final parsed = jsonDecode(controller.text);
      if (parsed is! Map) throw const FormatException('يجب أن يكون الجذر كائناً.');
      final imported = StudioDocument.fromJson(Map<String, dynamic>.from(parsed));
      if (!mounted) return;
      setState(() { _doc = imported; _selectedId = null; _preview = false; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('رفض الاستيراد: $e')));
    }
  }

  void _undoChange() {
    if (_undo.isEmpty) return;
    _redo.add(_doc);
    setState(() { _doc = _undo.removeLast(); _selectedId = null; });
  }

  void _redoChange() {
    if (_redo.isEmpty) return;
    _undo.add(_doc);
    setState(() { _doc = _redo.removeLast(); _selectedId = null; });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8FC),
        appBar: AppBar(
          title: const Text('Silsila Studio – استوديو التصميم والتطوير'),
          backgroundColor: _studioPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(tooltip: 'تراجع', onPressed: _undo.isEmpty ? null : _undoChange, icon: const Icon(Icons.undo)),
            IconButton(tooltip: 'إعادة', onPressed: _redo.isEmpty ? null : _redoChange, icon: const Icon(Icons.redo)),
            IconButton(tooltip: 'فتح تصميم', onPressed: _open, icon: const Icon(Icons.folder_open)),
            IconButton(tooltip: 'استيراد JSON', onPressed: _import, icon: const Icon(Icons.file_open)),
            IconButton(tooltip: 'تصدير JSON', onPressed: _export, icon: const Icon(Icons.code)),
            IconButton(tooltip: 'حفظ مسودة', onPressed: _busy ? null : _save, icon: const Icon(Icons.save)),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(children: [
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Wrap(spacing: 5, runSpacing: 5, children: [
                _command('تصميم جديد', Icons.add, () => setState(() { _doc = StudioDocument.create('شاشة جديدة'); _selectedId = null; _preview = false; })),
                _command(_preview ? 'العودة للمحرر' : 'معاينة', Icons.preview, () => setState(() => _preview = !_preview)),
                _command('اختبار المخطط', Icons.fact_check_outlined, () {
                  try { StudioDocument.fromJson(_doc.toJson()); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مخطط التصميم سليم.'))); }
                  catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'))); }
                }),
                _command('حفظ سحابياً', Icons.cloud_upload_outlined, _busy ? () {} : _saveCloud),
                _command('التصميمات السحابية', Icons.cloud_done_outlined, _busy ? () {} : _openCloud),
                _command('سجل الإصدارات', Icons.history, _doc.remoteId == null ? () => _notice('احفظ التصميم سحابياً أولاً.') : () => _showVersions(_doc.remoteId!)),
                _command('اعتماد الإصدار', Icons.verified_outlined, _approveCurrent),
                _command('نشر الإصدار', Icons.publish, _publishCurrent),
                _command('ربط بقاعدة البيانات', Icons.link, () => _notice('تعريف مصادر البيانات ومراجعة الحقول واختبار العمليات لم يُفعّل بعد.')),
                _command('اختبار ربط البيانات', Icons.link, () => _notice('تعريف مصادر البيانات ومراجعة الحقول واختبار العمليات ما زال قيد التنفيذ.')),
              ]),
            ),
          ),
          Expanded(child: _preview
            ? Container(color: Colors.white, margin: const EdgeInsets.all(8), child: StudioDocumentRenderer(document: _doc, interactive: true))
            : wide
              ? Row(children: [
                  SizedBox(width: 190, child: _toolbox()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _canvas()),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 250, child: _properties()),
                ])
              : Column(children: [
                  SizedBox(height: 112, child: _toolbox()),
                  Expanded(child: _canvas()),
                  SizedBox(height: 180, child: _properties()),
                ]),
          ),
          Container(
            height: 30, color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              const Icon(Icons.circle, size: 8, color: Colors.green),
              const SizedBox(width: 5),
              Text(_busy ? 'جارٍ الحفظ...' : 'مسودة محلية • ${_doc.nodes.length} مكون • غير منشور', style: const TextStyle(fontSize: 11)),
              const Spacer(),
              const Text('Schema v1', style: TextStyle(fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _command(String label, IconData icon, VoidCallback action) => OutlinedButton.icon(
    onPressed: action, icon: Icon(icon, size: 16), label: Text(label),
    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: _studioPurple),
  );

  Widget _toolbox() {
    final items = StudioComponentRegistry.supportedTypes.entries.toList();
    return ListView(
      padding: const EdgeInsets.all(6),
      scrollDirection: MediaQuery.sizeOf(context).width >= 1050 ? Axis.vertical : Axis.horizontal,
      children: [
        const Padding(padding: EdgeInsets.all(6), child: Text('مكتبة المكونات', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final item in items)
          SizedBox(width: 165, child: ListTile(
            dense: true, leading: const Icon(Icons.add_box_outlined, color: _studioPurple),
            title: Text(item.value, style: const TextStyle(fontSize: 12)),
            onTap: () => _add(item.key),
          )),
      ],
    );
  }

  Widget _canvas() => Container(
    margin: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE3DCEB)), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 10), color: const Color(0xFFF5EFFB),
        child: Row(children: [const Text('مساحة التصميم', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text(_doc.name, style: const TextStyle(fontSize: 11))])),
      Expanded(child: ReorderableListView(
        padding: const EdgeInsets.all(10),
        onReorder: (oldIndex, newIndex) {
          final nodes = [..._doc.nodes];
          if (newIndex > oldIndex) newIndex--;
          final node = nodes.removeAt(oldIndex);
          nodes.insert(newIndex, node);
          _change(_doc.copyWith(nodes: nodes));
        },
        children: [
          for (final node in _doc.nodes)
            Container(
              key: ValueKey(node.id),
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                border: Border.all(color: node.id == _selectedId ? _studioOrange : const Color(0xFFE8E1ED), width: node.id == _selectedId ? 2 : 1),
                borderRadius: BorderRadius.circular(5),
                color: node.id == _selectedId ? const Color(0xFFFFF8EA) : Colors.white,
              ),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.drag_indicator),
                title: StudioComponentRegistry.build(node),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {
                  _change(_doc.copyWith(nodes: _doc.nodes.where((e) => e.id != node.id).toList()));
                  setState(() => _selectedId = null);
                }),
                onTap: () => setState(() => _selectedId = node.id),
              ),
            ),
        ],
      )),
    ]),
  );

  Widget _properties() {
    final node = _selected;
    if (node == null) return const Center(child: Text('حدد مكوناً لعرض خصائصه.'));
    final fields = node.props.keys.toList();
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Text('خصائص المكون', style: TextStyle(fontWeight: FontWeight.bold, color: _studioPurple)),
        Text('النوع: ${StudioComponentRegistry.supportedTypes[node.type]}', style: const TextStyle(fontSize: 11)),
        for (final key in fields)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: TextFormField(
              key: ValueKey('${node.id}_$key'),
              initialValue: node.props[key]?.toString() ?? '',
              decoration: InputDecoration(labelText: key, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.all(8)),
              onFieldSubmitted: (value) {
                final props = Map<String, dynamic>.from(node.props);
                final old = props[key];
                props[key] = old is num ? num.tryParse(value) ?? old : old is bool ? value.toLowerCase() == 'true' : value;
                _change(_doc.copyWith(nodes: _doc.nodes.map((e) => e.id == node.id ? e.copyWith(props: props) : e).toList()));
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () {
          _change(_doc.copyWith(nodes: _doc.nodes.where((e) => e.id != node.id).toList()));
          setState(() => _selectedId = null);
        }, icon: const Icon(Icons.delete_outline), label: const Text('حذف المكون')),
      ],
    );
  }

  void _notice(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Silsila Studio'),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
    ),
  );
}
