import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/erp_studio_draft_store.dart';
import '../services/erp_studio_repository.dart';
import '../services/studio_data_sources.dart';
import '../services/studio_document.dart';
import '../services/studio_renderer.dart';
import 'erp_screen_layout_studio_screen.dart';

const _studioPurple = Color(0xFF3E007D);
const _studioOrange = Color(0xFFFFA015);
const _studioCanvas = Color(0xFFFAF8FC);

class SilsilaStudioScreen extends StatefulWidget {
  const SilsilaStudioScreen({super.key, this.companyId});
  final String? companyId;

  @override
  State<SilsilaStudioScreen> createState() => _SilsilaStudioScreenState();
}

class _SilsilaStudioScreenState extends State<SilsilaStudioScreen> {
  final _store = StudioDraftStore();
  final _repository = ErpStudioRepository();
  final _nameController = TextEditingController(text: 'شاشة جديدة');

  StudioDocument _doc = StudioDocument.create('شاشة جديدة');
  final Set<String> _selectedIds = <String>{};
  final List<StudioDocument> _undo = <StudioDocument>[];
  final List<StudioDocument> _redo = <StudioDocument>[];
  List<Map<String, dynamic>> _remoteDesigns = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _versions = <Map<String, dynamic>>[];
  Map<String, List<Map<String, dynamic>>> _previewData = {};
  String? _selectedSource;
  String? _selectedField;
  String _remoteStatus = 'draft';
  String? _remoteDesignId;
  int _remoteRevision = 0;
  int? _testedRevision;
  int _activeTab = 0;
  bool _preview = false;
  bool _busy = false;
  bool _dirty = false;
  String? _lastTestReport;

  static const _studioTabs = <String>[
    'لوحة الاستوديو',
    'مصمم الشاشات',
    'مصمم التقارير',
    'مصمم الأيقونات والعناصر',
    'مصمم الجداول وGrid',
    'مصادر البيانات والربط',
    'تخطيط وتنسيق الشاشات',
    'المعاينة والاختبار',
    'الإصدارات والاستعادة',
    'الاعتماد والنشر',
  ];

  StudioNode? get _selected {
    for (final node in _doc.nodes) {
      if (_selectedIds.contains(node.id)) return node;
    }
    return null;
  }

  String? get _companyId =>
      widget.companyId != null && widget.companyId!.trim().isNotEmpty
          ? widget.companyId
          : null;

  @override
  void initState() {
    super.initState();
    _nameController.text = _doc.name;
    if (_companyId != null) {
      _loadRemoteDesigns();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade800 : _studioPurple,
    ));
  }

  void _change(StudioDocument next) {
    _undo.add(_doc);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
    setState(() {
      _doc = next;
      _dirty = true;
      _testedRevision = null;
      _lastTestReport = null;
    });
    _store.save(_doc).catchError((Object error) {
      _notice('تعذر حفظ نسخة العمل المحلية: $error', error: true);
    });
  }

  void _newDesign(String kind) {
    final labels = <String, String>{
      'screen': 'شاشة جديدة',
      'report': 'تقرير جديد',
      'icon': 'مجموعة أيقونات',
      'table': 'جدول جديد',
      'grid': 'شبكة جديدة',
      'tree': 'شجرة بيانات',
      'form': 'نموذج جديد',
      'component': 'عنصر مشترك جديد',
    };
    final next = StudioDocument.create(labels[kind] ?? 'تصميم جديد', designKind: kind);
    setState(() {
      _doc = next;
      _nameController.text = next.name;
      _selectedIds.clear();
      _preview = false;
      _remoteDesignId = null;
      _remoteRevision = 0;
      _remoteStatus = 'draft';
      _dirty = true;
      _testedRevision = null;
      _previewData = {};
      _activeTab = kind == 'report' ? 2 : kind == 'icon' ? 3 : kind == 'table' || kind == 'grid' || kind == 'tree' ? 4 : 1;
    });
    _store.save(next);
  }

  Map<String, dynamic> _defaultProps(String type) {
    switch (type) {
      case 'text':
        return {'text': 'نص جديد', 'size': 14};
      case 'button':
        return {'text': 'زر جديد', 'icon': 'check'};
      case 'field':
        return {'label': 'اسم الحقل', 'hint': 'أدخل القيمة'};
      case 'card':
      case 'container':
        return {'title': 'بطاقة جديدة', 'subtitle': 'وصف البطاقة'};
      case 'spacer':
        return {'height': 10};
      case 'grid':
        return {'columns': 2, 'labelField': 'item_name'};
      case 'tree':
      case 'list':
        return {'field': 'item_name'};
      case 'table':
        return {'columns': ['item_code', 'item_name', 'base_unit']};
      case 'icon':
        return {'name': 'dashboard', 'size': 32, 'color': 0xFF3E007D};
      case 'image':
        return {'height': 120, 'url': ''};
      case 'chart':
        return {'valueField': 'grand_total', 'labelField': 'document_number'};
      case 'tabs':
        return {'labels': ['بيانات', 'حركات', 'تقارير']};
      case 'form':
        return {'fields': ['الاسم', 'الكود']};
      case 'badge':
        return {'text': 'نشط', 'color': 0xFF26A69A};
      case 'progress':
        return {'label': 'نسبة الإنجاز', 'value': .65};
      case 'stat':
        return {'label': 'إجمالي السجلات', 'value': '0'};
      case 'filter':
        return {'hint': 'بحث وتصفية'};
      default:
        return {};
    }
  }

  void _add(String type, {Map<String, dynamic>? props}) {
    if (_doc.nodes.length >= 500) {
      _notice('وصل التصميم إلى الحد الأقصى وهو 500 مكون.', error: true);
      return;
    }
    final id = '${type}_${DateTime.now().microsecondsSinceEpoch}';
    final node = StudioNode(id: id, type: type, props: props ?? _defaultProps(type));
    _change(_doc.copyWith(nodes: [..._doc.nodes, node]));
    setState(() {
      _selectedIds
        ..clear()
        ..add(id);
    });
  }

  void _updateNode(StudioNode node, {Map<String, dynamic>? props, bool? hidden, bool? locked, String? groupId, bool clearGroup = false}) {
    if (node.locked && locked != false) {
      _notice('هذا المكون مقفل. أزل القفل أولاً لتعديله.');
      return;
    }
    final next = node.copyWith(
      props: props,
      hidden: hidden,
      locked: locked,
      groupId: groupId,
      clearGroup: clearGroup,
    );
    _change(_doc.copyWith(nodes: _doc.nodes.map((e) => e.id == node.id ? next : e).toList()));
  }

  void _renameDesign(String value) {
    final name = value.trim();
    if (name.isEmpty) return;
    _change(_doc.copyWith(name: name));
  }

  void _duplicateSelected() {
    final selected = _doc.nodes.where((n) => _selectedIds.contains(n.id) && !n.locked).toList();
    if (selected.isEmpty) return;
    final copies = selected.map((node) => StudioNode(
      id: '${node.type}_${DateTime.now().microsecondsSinceEpoch}_${selected.indexOf(node)}',
      type: node.type,
      props: Map<String, dynamic>.from(node.props),
      hidden: node.hidden,
      locked: false,
    )).toList();
    _change(_doc.copyWith(nodes: [..._doc.nodes, ...copies]));
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(copies.map((e) => e.id));
    });
  }

  void _deleteSelected() {
    final removable = _doc.nodes.where((n) => _selectedIds.contains(n.id) && !n.locked).toList();
    if (removable.isEmpty) {
      _notice('لا توجد مكونات محددة قابلة للحذف.');
      return;
    }
    final ids = removable.map((e) => e.id).toSet();
    _change(_doc.copyWith(nodes: _doc.nodes.where((e) => !ids.contains(e.id)).toList()));
    setState(() => _selectedIds.clear());
  }

  void _groupSelected() {
    if (_selectedIds.length < 2) {
      _notice('حدد مكونين على الأقل لإنشاء مجموعة.');
      return;
    }
    final groupId = 'group_${DateTime.now().microsecondsSinceEpoch}';
    _change(_doc.copyWith(nodes: _doc.nodes.map((node) =>
      _selectedIds.contains(node.id) ? node.copyWith(groupId: groupId) : node).toList()));
    _notice('تم تجميع العناصر المحددة.');
  }

  void _ungroupSelected() {
    if (_selectedIds.isEmpty) return;
    _change(_doc.copyWith(nodes: _doc.nodes.map((node) =>
      _selectedIds.contains(node.id) ? node.copyWith(clearGroup: true) : node).toList()));
  }

  void _toggleLock(StudioNode node) => _updateNode(node, locked: !node.locked);
  void _toggleHidden(StudioNode node) => _updateNode(node, hidden: !node.hidden);

  void _undoChange() {
    if (_undo.isEmpty) return;
    _redo.add(_doc);
    setState(() {
      _doc = _undo.removeLast();
      _selectedIds.clear();
      _dirty = true;
      _testedRevision = null;
    });
  }

  void _redoChange() {
    if (_redo.isEmpty) return;
    _undo.add(_doc);
    setState(() {
      _doc = _redo.removeLast();
      _selectedIds.clear();
      _dirty = true;
      _testedRevision = null;
    });
  }

  Future<void> _saveLocal() async {
    setState(() => _busy = true);
    try {
      await _store.save(_doc);
      _notice('تم حفظ المسودة محلياً على هذا الجهاز.');
    } catch (e) {
      _notice('تعذر الحفظ المحلي: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCloud() async {
    final company = _companyId;
    if (company == null) {
      _notice('يجب اختيار شركة نشطة قبل الحفظ المركزي.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await _repository.saveDraft(
        companyId: company,
        document: _doc,
        designKey: 'studio_${_doc.id}',
        remoteId: _remoteDesignId ?? _doc.remoteId,
        expectedRevision: _remoteRevision == 0 ? null : _remoteRevision,
      );
      final nextRevision = _remoteRevision + 1;
      final next = _doc.copyWith(remoteId: id, remoteRevision: nextRevision);
      await _store.save(next);
      if (!mounted) return;
      setState(() {
        _doc = next;
        _remoteDesignId = id;
        _remoteRevision = nextRevision;
        _remoteStatus = 'draft';
        _dirty = false;
        _testedRevision = null;
      });
      await _loadRemoteDesigns();
      _notice('تم الحفظ المركزي كإصدار $nextRevision.');
    } catch (e) {
      _notice('تعذر الحفظ المركزي. قد يكون هناك تعارض إصدار أو صلاحية غير كافية: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncCurrentDraft() async {
    if (_doc.remoteId == null || _remoteRevision == 0) {
      await _saveCloud();
      return;
    }
    await _saveCloud();
  }

  Future<void> _openLocalDrafts() async {
    try {
      final drafts = await _store.list();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('المسودات المحلية'),
          content: SizedBox(
            width: 480,
            child: drafts.isEmpty
                ? const Text('لا توجد مسودات محفوظة على هذا الجهاز.')
                : ListView(shrinkWrap: true, children: drafts.map((draft) => ListTile(
                    title: Text(draft.name),
                    subtitle: Text('${draft.designKind} • ${draft.nodes.length} مكون • إصدار مركزي ${draft.remoteRevision}'),
                    onTap: () {
                      setState(() {
                        _doc = draft;
                        _nameController.text = draft.name;
                        _remoteDesignId = draft.remoteId;
                        _remoteRevision = draft.remoteRevision;
                        _remoteStatus = 'draft';
                        _selectedIds.clear();
                        _dirty = false;
                        _testedRevision = null;
                      });
                      Navigator.pop(dialogContext);
                    },
                    trailing: IconButton(
                      tooltip: 'حذف المسودة المحلية',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _store.delete(draft.id);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _openLocalDrafts();
                      },
                    ),
                  )).toList()),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
        ),
      );
    } catch (e) {
      _notice('تعذر قراءة المسودات: $e', error: true);
    }
  }

  Future<void> _exportJson() async {
    await Clipboard.setData(ClipboardData(text: _doc.encode()));
    _notice('تم نسخ ملف التصميم بصيغة JSON إلى الحافظة.');
  }

  Future<void> _importJson() async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استيراد تصميم JSON'),
        content: SizedBox(width: 560, child: TextField(
          controller: controller,
          minLines: 6,
          maxLines: 14,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'الصق تعريف JSON هنا',
          ),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تحقق واستيراد')),
        ],
      ),
    );
    if (accepted != true) {
      controller.dispose();
      return;
    }
    try {
      final parsed = jsonDecode(controller.text);
      if (parsed is! Map) throw const FormatException('يجب أن يكون جذر الملف كائناً.');
      final importMap = Map<String, dynamic>.from(parsed)..remove('remoteId')..['remoteRevision'] = 0;
      final imported = StudioDocument.fromJson(importMap);
      setState(() {
        _doc = imported;
        _nameController.text = imported.name;
        _remoteDesignId = null;
        _remoteRevision = 0;
        _remoteStatus = 'draft';
        _selectedIds.clear();
        _preview = false;
        _dirty = true;
        _testedRevision = null;
      });
      await _store.save(imported);
      _notice('تم التحقق من التصميم واستيراده كمسودة محلية.');
    } catch (e) {
      _notice('رفض الاستيراد: $e', error: true);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _loadRemoteDesigns() async {
    final company = _companyId;
    if (company == null) return;
    try {
      final rows = await _repository.listDesigns(company);
      if (mounted) setState(() => _remoteDesigns = rows);
    } catch (e) {
      if (mounted) _notice('تعذر تحميل التصميمات المركزية: $e', error: true);
    }
  }

  Future<void> _loadRemoteDesign(String id) async {
    final company = _companyId;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      final row = await _repository.getDesign(companyId: company, designId: id);
      final raw = row['design_json'];
      if (raw is! Map) throw const FormatException('مخطط التصميم المركزي غير صالح.');
      final decoded = StudioDocument.fromJson(Map<String, dynamic>.from(raw));
      final revision = (row['revision'] as num?)?.toInt() ?? 0;
      final next = decoded.copyWith(remoteId: id, remoteRevision: revision);
      await _store.save(next);
      if (!mounted) return;
      setState(() {
        _doc = next;
        _nameController.text = next.name;
        _remoteDesignId = id;
        _remoteRevision = revision;
        _remoteStatus = row['status']?.toString() ?? 'draft';
        _selectedIds.clear();
        _dirty = false;
        _testedRevision = null;
        _preview = false;
      });
      await _loadVersions();
      _notice('تم فتح التصميم المركزي — الإصدار $revision.');
    } catch (e) {
      _notice('تعذر فتح التصميم: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadVersions() async {
    final company = _companyId;
    final id = _remoteDesignId;
    if (company == null || id == null) {
      setState(() => _versions = []);
      return;
    }
    try {
      final rows = await _repository.listVersions(companyId: company, designId: id);
      if (mounted) setState(() => _versions = rows);
    } catch (e) {
      _notice('تعذر تحميل سجل الإصدارات: $e', error: true);
    }
  }

  Future<void> _restoreVersion(int revision) async {
    final company = _companyId;
    final id = _remoteDesignId;
    if (company == null || id == null) return;
    setState(() => _busy = true);
    try {
      final nextRevision = await _repository.restoreVersion(
        companyId: company,
        designId: id,
        targetRevision: revision,
        expectedRevision: _remoteRevision,
      );
      await _loadRemoteDesign(id);
      if (!mounted) return;
      setState(() {
        _remoteRevision = nextRevision;
        _doc = _doc.copyWith(remoteRevision: nextRevision);
        _remoteStatus = 'draft';
        _testedRevision = null;
      });
      _notice('تمت استعادة محتوى الإصدار $revision في إصدار جديد رقم $nextRevision.');
    } catch (e) {
      _notice('فشلت الاستعادة: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runTests() async {
    setState(() => _busy = true);
    final errors = <String>[];
    final notes = <String>[];
    try {
      StudioDocument.fromJson(_doc.toJson());
      for (final node in _doc.nodes) {
        final binding = node.props['binding'];
        if (binding is Map && binding['source'] is String) {
          try {
            final source = StudioDataSources.byKey(binding['source'] as String);
            final field = binding['field']?.toString();
            if (field != null && !source.columns.contains(field)) {
              errors.add('الحقل $field غير مسموح في مصدر ${source.label}.');
            }
          } catch (e) {
            errors.add(e.toString());
          }
        }
      }
      final company = _companyId;
      if (company != null) {
        _previewData = await _repository.previewBindings(companyId: company, document: _doc, limit: 50);
        notes.add('تم اختبار مصادر البيانات الفعلية بصلاحيات المستخدم الحالي.');
      } else {
        notes.add('تم اختبار بنية التصميم فقط؛ لم تُختبر قاعدة البيانات لعدم تحديد شركة نشطة.');
      }
      if (_doc.nodes.any((n) => n.locked && n.hidden)) {
        notes.add('يوجد مكون مقفل ومخفي؛ تحقق من ظهوره قبل الاعتماد.');
      }
      if (errors.isEmpty) {
        _testedRevision = _remoteDesignId == null ? null : _remoteRevision;
        _lastTestReport = 'نجح اختبار مخطط التصميم والروابط.\n${notes.join('\n')}';
        _notice('نجحت اختبارات التصميم.');
      } else {
        _testedRevision = null;
        _lastTestReport = 'فشل الاختبار:\n${errors.join('\n')}';
        _notice('فشل الاختبار: ${errors.length} مشكلة.', error: true);
      }
    } catch (e) {
      _testedRevision = null;
      _lastTestReport = 'فشل الاختبار: $e';
      _notice('فشل اختبار التصميم: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveDesign() async {
    final company = _companyId;
    final id = _remoteDesignId;
    if (company == null || id == null) {
      _notice('احفظ التصميم مركزياً أولاً.', error: true);
      return;
    }
    if (_dirty || _testedRevision != _remoteRevision) {
      _notice('احفظ آخر تعديل ثم شغّل الاختبارات على نفس الإصدار قبل الاعتماد.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repository.approve(companyId: company, designId: id, expectedRevision: _remoteRevision);
      setState(() => _remoteStatus = 'approved');
      await _loadRemoteDesigns();
      _notice('تم اعتماد الإصدار $_remoteRevision.');
    } catch (e) {
      _notice('تعذر اعتماد التصميم: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishDesign() async {
    final company = _companyId;
    final id = _remoteDesignId;
    if (company == null || id == null) return;
    if (_remoteStatus != 'approved' || _testedRevision != _remoteRevision || _dirty) {
      _notice('يجب حفظ الإصدار الحالي واختباره واعتماده قبل النشر.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repository.publish(companyId: company, designId: id, testedRevision: _remoteRevision);
      setState(() => _remoteStatus = 'published');
      await _loadRemoteDesigns();
      _notice('تم نشر التصميم المركزي.');
    } catch (e) {
      _notice('تعذر النشر: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewSource() async {
    final company = _companyId;
    final source = _selectedSource;
    if (company == null || source == null) {
      _notice('حدد شركة ومصدر بيانات أولاً.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final rows = await _repository.previewSource(companyId: company, sourceKey: source, limit: 20);
      setState(() => _previewData = {..._previewData, source: rows});
      _notice('تم جلب ${rows.length} سجل من المصدر المحدد.');
    } catch (e) {
      _notice('تعذر قراءة المصدر: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyBinding() {
    final node = _selected;
    final source = _selectedSource;
    final field = _selectedField;
    if (node == null || source == null || field == null) {
      _notice('حدد المكون ومصدر البيانات والحقل.');
      return;
    }
    final binding = {'source': source, 'field': field, 'mode': 'read'};
    final props = Map<String, dynamic>.from(node.props)..['binding'] = binding;
    _updateNode(node, props: props);
    _change(_doc.copyWith(bindings: {..._doc.bindings, node.id: binding}));
    _notice('تم ربط المكون بمصدر البيانات. احفظ التصميم مركزياً لتثبيت الربط.');
  }

  void _clearBinding() {
    final node = _selected;
    if (node == null) return;
    final props = Map<String, dynamic>.from(node.props)..remove('binding');
    final bindings = Map<String, dynamic>.from(_doc.bindings)..remove(node.id);
    _updateNode(node, props: props);
    _change(_doc.copyWith(bindings: bindings));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _studioCanvas,
        appBar: AppBar(
          title: const Text('سلسلة ستوديو'),
          backgroundColor: _studioPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(tooltip: 'تراجع', onPressed: _undo.isEmpty ? null : _undoChange, icon: const Icon(Icons.undo)),
            IconButton(tooltip: 'إعادة', onPressed: _redo.isEmpty ? null : _redoChange, icon: const Icon(Icons.redo)),
            IconButton(tooltip: 'فتح المسودات المحلية', onPressed: _openLocalDrafts, icon: const Icon(Icons.folder_open)),
            IconButton(tooltip: 'استيراد JSON', onPressed: _importJson, icon: const Icon(Icons.file_open)),
            IconButton(tooltip: 'تصدير JSON', onPressed: _exportJson, icon: const Icon(Icons.code)),
            IconButton(tooltip: 'حفظ محلي', onPressed: _busy ? null : _saveLocal, icon: const Icon(Icons.save_outlined)),
            IconButton(tooltip: 'حفظ مركزي ومزامنة', onPressed: _busy ? null : _syncCurrentDraft, icon: const Icon(Icons.cloud_upload_outlined)),
          ],
        ),
        body: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < _studioTabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(_studioTabs[i]),
                      selected: _activeTab == i,
                      selectedColor: const Color(0xFFF0E7FA),
                      labelStyle: TextStyle(
                        color: _activeTab == i ? _studioPurple : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() => _activeTab = i),
                    ),
                  ),
              ]),
            ),
          ),
          if (_activeTab == 0) _overviewPanel(),
          if (_activeTab >= 1 && _activeTab <= 4) _designerPanel(wide),
          if (_activeTab == 5) _dataBindingPanel(),
          if (_activeTab == 6) const Expanded(child: ErpScreenLayoutStudioScreen()),
          if (_activeTab == 7) _testPanel(),
          if (_activeTab == 8) _versionsPanel(),
          if (_activeTab == 9) _approvalPanel(),
          if (_activeTab != 6) _statusBar(),
        ]),
      ),
    );
  }

  Widget _overviewPanel() => Expanded(
    child: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('مساحة التصميم والتطوير الموحدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _studioPurple)),
        const SizedBox(height: 6),
        const Text('أنشئ الشاشات والتقارير والجداول والعناصر، اربطها بمصادر بيانات محددة، اختبرها، ثم اعتمدها وانشرها مع سجل إصدارات قابل للاستعادة.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metricCard('المكونات الحالية', '${_doc.nodes.length}', Icons.widgets_outlined),
          _metricCard('التصميمات المركزية', '${_remoteDesigns.length}', Icons.cloud_outlined),
          _metricCard('الإصدار الحالي', '$_remoteRevision', Icons.history),
          _metricCard('الحالة', _statusLabel(_remoteStatus), Icons.verified_outlined),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _actionCard('مصمم الشاشات', Icons.web, () => setState(() => _activeTab = 1)),
          _actionCard('مصمم التقارير', Icons.assessment_outlined, () => setState(() => _activeTab = 2)),
          _actionCard('الأيقونات والعناصر', Icons.widgets_outlined, () => setState(() => _activeTab = 3)),
          _actionCard('الجداول وGrid', Icons.table_chart_outlined, () => setState(() => _activeTab = 4)),
          _actionCard('مصادر البيانات', Icons.link, () => setState(() => _activeTab = 5)),
          _actionCard('تخطيط الواجهات', Icons.dashboard_customize_outlined, () => setState(() => _activeTab = 6)),
          _actionCard('المعاينة والاختبار', Icons.fact_check_outlined, () => setState(() => _activeTab = 7)),
          _actionCard('الإصدارات والاستعادة', Icons.history, () => setState(() => _activeTab = 8)),
          _actionCard('الاعتماد والنشر', Icons.publish_outlined, () => setState(() => _activeTab = 9)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          const Text('التصميمات المركزية الأخيرة', style: TextStyle(fontWeight: FontWeight.w900, color: _studioPurple)),
          const Spacer(),
          TextButton.icon(onPressed: _loadRemoteDesigns, icon: const Icon(Icons.refresh), label: const Text('تحديث')),
        ]),
        if (_companyId == null)
          const Text('اختر شركة نشطة لعرض التصميمات المركزية ومزامنتها.')
        else if (_remoteDesigns.isEmpty)
          const Text('لا توجد تصميمات مركزية أو لم يتم تحميلها بعد.')
        else
          ..._remoteDesigns.take(10).map((row) => Card(
            child: ListTile(
              leading: const Icon(Icons.design_services, color: _studioPurple),
              title: Text((row['name'] ?? '').toString()),
              subtitle: Text('${row['design_kind']} • ${_statusLabel(row['status']?.toString() ?? 'draft')} • الإصدار ${row['revision']}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _loadRemoteDesign(row['id'].toString()),
            ),
          )),
      ],
    ),
  );

  Widget _metricCard(String label, String value, IconData icon) => SizedBox(
    width: 190,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(icon, color: _studioPurple),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _studioPurple)),
        ])),
      ]),
    )),
  );

  Widget _actionCard(String label, IconData icon, VoidCallback action) => SizedBox(
    width: 220,
    child: Card(child: ListTile(
      leading: Icon(icon, color: _studioPurple),
      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 13),
      onTap: action,
    )),
  );

  Widget _designerPanel(bool wide) => Expanded(
    child: Column(children: [
      Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Wrap(spacing: 5, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 190, child: TextFormField(
              controller: _nameController,
              onFieldSubmitted: _renameDesign,
              decoration: const InputDecoration(labelText: 'اسم التصميم', isDense: true),
            )),
            _command('تصميم جديد', Icons.add, () => _newDesign(_activeTab == 2 ? 'report' : _activeTab == 3 ? 'icon' : _activeTab == 4 ? 'table' : 'screen')),
            _command(_preview ? 'المحرر' : 'المعاينة', Icons.preview, () => setState(() => _preview = !_preview)),
            _command('اختبار', Icons.fact_check_outlined, _runTests),
            _command('حفظ مركزي', Icons.cloud_upload_outlined, _busy ? () {} : _saveCloud),
            _command('نسخ العنصر', Icons.copy, _duplicateSelected),
            _command('تجميع', Icons.folder_copy_outlined, _groupSelected),
            _command('فك التجميع', Icons.folder_open, _ungroupSelected),
            _command('حذف المحدد', Icons.delete_outline, _deleteSelected),
          ]),
        ),
      ),
      Expanded(
        child: _preview
            ? Container(
                color: Colors.white,
                margin: const EdgeInsets.all(8),
                child: StudioDocumentRenderer(document: _doc, dataBySource: _previewData),
              )
            : wide
                ? Row(children: [
                    SizedBox(width: 190, child: _toolbox()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _canvas()),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 270, child: _properties()),
                  ])
                : Column(children: [
                    SizedBox(height: 112, child: _toolbox()),
                    Expanded(child: _canvas()),
                    SizedBox(height: 230, child: _properties()),
                  ]),
      ),
    ]),
  );

  Widget _toolbox() {
    Iterable<MapEntry<String, String>> items = StudioComponentRegistry.supportedTypes.entries;
    if (_activeTab == 2) {
      items = items.where((e) => {'text', 'chart', 'table', 'stat', 'filter', 'badge', 'progress', 'image'}.contains(e.key));
    } else if (_activeTab == 3) {
      items = items.where((e) => {'icon', 'image', 'badge', 'button', 'text', 'card'}.contains(e.key));
    } else if (_activeTab == 4) {
      items = items.where((e) => {'table', 'grid', 'tree', 'list', 'filter', 'tabs', 'form'}.contains(e.key));
    }
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(6),
        scrollDirection: MediaQuery.sizeOf(context).width >= 1050 ? Axis.vertical : Axis.horizontal,
        children: [
          const Padding(padding: EdgeInsets.all(6), child: Text('مكتبة المكونات', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final item in items)
            SizedBox(width: 165, child: ListTile(
              dense: true,
              leading: const Icon(Icons.add_box_outlined, color: _studioPurple),
              title: Text(item.value, style: const TextStyle(fontSize: 12)),
              onTap: () => _add(item.key),
            )),
          if (_activeTab == 3)
            for (final entry in StudioComponentRegistry.iconNames.entries)
              SizedBox(width: 150, child: ListTile(
                dense: true,
                leading: Icon(entry.value, color: _studioPurple),
                title: Text(entry.key, style: const TextStyle(fontSize: 11)),
                onTap: () => _add('icon', props: {'name': entry.key, 'size': 32, 'color': 0xFF3E007D}),
              )),
        ],
      ),
    );
  }

  Widget _canvas() => Container(
    margin: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE3DCEB)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: [
      Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: const Color(0xFFF5EFFB),
        child: Row(children: [
          const Text('مساحة التصميم والطبقات', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_doc.nodes.length} مكون • ${_selectedIds.length} محدد', style: const TextStyle(fontSize: 11)),
        ]),
      ),
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
                border: Border.all(
                  color: _selectedIds.contains(node.id) ? _studioOrange : const Color(0xFFE8E1ED),
                  width: _selectedIds.contains(node.id) ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(5),
                color: node.hidden ? const Color(0xFFF2F0F4) : _selectedIds.contains(node.id) ? const Color(0xFFFFF8EA) : Colors.white,
              ),
              child: ListTile(
                dense: true,
                leading: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                    value: _selectedIds.contains(node.id),
                    onChanged: node.locked ? null : (value) => setState(() {
                      if (value == true) { _selectedIds.add(node.id); } else { _selectedIds.remove(node.id); }
                    }),
                  ),
                  const Icon(Icons.drag_indicator),
                ]),
                title: Opacity(
                  opacity: node.hidden ? .45 : 1,
                  child: StudioComponentRegistry.build(node, dataBySource: _previewData),
                ),
                subtitle: Text('${StudioComponentRegistry.supportedTypes[node.type]} • ${node.groupId ?? 'بدون مجموعة'}${node.locked ? ' • مقفل' : ''}'),
                trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: node.hidden ? 'إظهار' : 'إخفاء',
                    icon: Icon(node.hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: () => _toggleHidden(node),
                  ),
                  IconButton(
                    tooltip: node.locked ? 'إلغاء القفل' : 'قفل',
                    icon: Icon(node.locked ? Icons.lock_outline : Icons.lock_open_outlined, size: 18),
                    onPressed: () => _toggleLock(node),
                  ),
                ]),
                onTap: () => setState(() {
                  if (node.locked) {
                    _selectedIds
                      ..clear()
                      ..add(node.id);
                  } else {
                    _selectedIds
                      ..clear()
                      ..add(node.id);
                  }
                }),
              ),
            ),
        ],
      )),
    ]),
  );

  Widget _properties() {
    final node = _selected;
    if (node == null) {
      return const Center(child: Text('حدد مكوناً لعرض خصائصه. يمكنك تحديد عدة مكونات للتجميع.'));
    }
    if (node.locked) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outline, size: 30, color: _studioPurple),
        const Text('المكون مقفل'),
        OutlinedButton(onPressed: () => _toggleLock(node), child: const Text('إلغاء القفل')),
      ]));
    }
    final fields = node.props.keys.where((key) => key != 'binding').toList();
    final width = (node.props['width'] is num ? (node.props['width'] as num).toDouble() : 0).clamp(0, 1000).toDouble();
    final height = (node.props['height'] is num ? (node.props['height'] as num).toDouble() : 40).clamp(20, 500).toDouble();
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
              decoration: InputDecoration(
                labelText: key,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.all(8),
              ),
              onFieldSubmitted: (value) {
                final props = Map<String, dynamic>.from(node.props);
                final old = props[key];
                if (old is num) {
                  props[key] = num.tryParse(value) ?? old;
                } else if (old is bool) {
                  props[key] = value.toLowerCase() == 'true';
                } else {
                  props[key] = value;
                }
                _updateNode(node, props: props);
              },
            ),
          ),
        const SizedBox(height: 10),
        Text('العرض: ${width == 0 ? 'تلقائي' : width.toInt().toString()}', style: const TextStyle(fontSize: 11)),
        Slider(
          value: width,
          min: 0,
          max: 1000,
          divisions: 100,
          onChanged: (value) {
            final props = Map<String, dynamic>.from(node.props)..['width'] = value == 0 ? 'fill' : value;
            _updateNode(node, props: props);
          },
        ),
        Text('الارتفاع: ${height.toInt()} px', style: const TextStyle(fontSize: 11)),
        Slider(
          value: height,
          min: 20,
          max: 500,
          divisions: 48,
          onChanged: (value) {
            final props = Map<String, dynamic>.from(node.props)..['height'] = value;
            _updateNode(node, props: props);
          },
        ),
        const Divider(),
        OutlinedButton.icon(
          onPressed: () => setState(() => _activeTab = 5),
          icon: const Icon(Icons.link),
          label: const Text('إعداد ربط البيانات'),
        ),
        OutlinedButton.icon(
          onPressed: () => _toggleHidden(node),
          icon: Icon(node.hidden ? Icons.visibility : Icons.visibility_off),
          label: Text(node.hidden ? 'إظهار المكون' : 'إخفاء المكون'),
        ),
        OutlinedButton.icon(
          onPressed: () => _toggleLock(node),
          icon: const Icon(Icons.lock_outline),
          label: const Text('قفل المكون'),
        ),
      ],
    );
  }

  Widget _dataBindingPanel() {
    final node = _selected;
    final source = _selectedSource == null
        ? null
        : StudioDataSources.byKey(_selectedSource!);
    final fields = source?.columns ?? const <String>[];
    return Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
      const Text('مصادر البيانات والربط الآمن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _studioPurple)),
      const SizedBox(height: 6),
      const Text('مصادر القراءة هنا محددة مسبقاً ومقيدة بالشركة وصلاحيات Supabase. لا يسمح التصميم المستورد بتحديد أسماء جداول أو تنفيذ SQL حر.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 260, child: DropdownButtonFormField<String>(
          value: _selectedSource,
          decoration: const InputDecoration(labelText: 'مصدر البيانات'),
          items: StudioDataSources.all.map((s) => DropdownMenuItem(value: s.key, child: Text(s.label))).toList(),
          onChanged: (value) => setState(() {
            _selectedSource = value;
            _selectedField = value == null ? null : StudioDataSources.byKey(value).columns.first;
          }),
        )),
        SizedBox(width: 260, child: DropdownButtonFormField<String>(
          value: fields.contains(_selectedField) ? _selectedField : fields.isEmpty ? null : fields.first,
          decoration: const InputDecoration(labelText: 'الحقل'),
          items: fields.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
          onChanged: (value) => setState(() => _selectedField = value),
        )),
        SizedBox(width: 240, child: DropdownButtonFormField<String>(
          value: node?.id,
          decoration: const InputDecoration(labelText: 'المكون المستهدف'),
          items: _doc.nodes.map((n) => DropdownMenuItem(value: n.id, child: Text('${n.id} • ${StudioComponentRegistry.supportedTypes[n.type]}'))).toList(),
          onChanged: (value) => setState(() {
            _selectedIds
              ..clear()
              ..addIfNotNull(value);
          }),
        )),
        FilledButton.icon(onPressed: _busy ? null : _previewSource, icon: const Icon(Icons.preview), label: const Text('معاينة المصدر')),
        FilledButton.icon(onPressed: _applyBinding, icon: const Icon(Icons.link), label: const Text('ربط بالمكون')),
        OutlinedButton.icon(onPressed: _clearBinding, icon: const Icon(Icons.link_off), label: const Text('إلغاء الربط')),
      ]),
      const SizedBox(height: 14),
      if (_selectedSource != null) ...[
        Text('الحقول المسموح بها: ${fields.join(' • ')}', style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 8),
        _dataPreviewTable(_previewData[_selectedSource!] ?? const []),
      ],
      const SizedBox(height: 14),
      const Text('الروابط الحالية', style: TextStyle(fontWeight: FontWeight.w900, color: _studioPurple)),
      ..._doc.nodes.where((n) => n.props['binding'] is Map).map((n) {
        final b = Map<String, dynamic>.from(n.props['binding'] as Map);
        return Card(child: ListTile(
          leading: const Icon(Icons.link, color: _studioPurple),
          title: Text(n.id),
          subtitle: Text('${b['source']} → ${b['field']}'),
          trailing: IconButton(icon: const Icon(Icons.link_off), onPressed: () {
            setState(() => _selectedIds..clear()..add(n.id));
            _clearBinding();
          }),
        ));
      }),
    ]));
  }

  Widget _dataPreviewTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Text('لا توجد سجلات للعرض أو لم يتم جلب المصدر بعد.');
    final columns = rows.first.keys.take(6).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
        rows: rows.take(20).map((row) => DataRow(
          cells: columns.map((c) => DataCell(Text((row[c] ?? '').toString()))).toList(),
        )).toList(),
      ),
    );
  }

  Widget _testPanel() => Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
    const Text('المعاينة والاختبار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _studioPurple)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      FilledButton.icon(onPressed: _busy ? null : _runTests, icon: const Icon(Icons.fact_check), label: const Text('تشغيل جميع اختبارات التصميم والربط')),
      OutlinedButton.icon(onPressed: () => setState(() => _preview = !_preview), icon: const Icon(Icons.preview), label: Text(_preview ? 'إغلاق المعاينة' : 'فتح المعاينة')),
      OutlinedButton.icon(onPressed: _saveLocal, icon: const Icon(Icons.save), label: const Text('حفظ نسخة محلية')),
    ]),
    const SizedBox(height: 12),
    if (_lastTestReport == null)
      const Text('لم يتم تشغيل الاختبارات بعد. الاختبار يتحقق من سلامة المخطط، أنواع المكونات، ومصادر البيانات والحقول المرتبطة.')
    else
      Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(_lastTestReport!, style: const TextStyle(height: 1.6)),
      )),
    if (_preview)
      SizedBox(height: 520, child: StudioDocumentRenderer(document: _doc, dataBySource: _previewData)),
  ]));

  Widget _versionsPanel() => Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
    Row(children: [
      const Expanded(child: Text('الإصدارات والاستعادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _studioPurple))),
      OutlinedButton.icon(onPressed: _loadRemoteDesigns, icon: const Icon(Icons.refresh), label: const Text('تحديث التصميمات')),
    ]),
    const SizedBox(height: 8),
    if (_companyId == null)
      const Text('اختر شركة نشطة لعرض سجل الإصدارات المركزي.')
    else ...[
      DropdownButtonFormField<String>(
        value: _remoteDesigns.any((row) => row['id']?.toString() == _remoteDesignId) ? _remoteDesignId : null,
        decoration: const InputDecoration(labelText: 'التصميم المركزي'),
        items: _remoteDesigns.map((row) => DropdownMenuItem(
          value: row['id'].toString(),
          child: Text('${row['name']} • ${row['status']} • v${row['revision']}'),
        )).toList(),
        onChanged: (value) {
          if (value != null) _loadRemoteDesign(value);
        },
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _loadVersions, icon: const Icon(Icons.history), label: const Text('تحميل سجل الإصدارات')),
      if (_versions.isEmpty) const Text('لا توجد إصدارات محملة لهذا التصميم.')
      else ..._versions.map((version) => Card(child: ListTile(
        leading: const Icon(Icons.history, color: _studioPurple),
        title: Text('الإصدار ${version['revision']}'),
        subtitle: Text('${version['change_note'] ?? 'بدون ملاحظة'} • ${version['created_at']}'),
        trailing: TextButton(
          onPressed: _busy ? null : () => _restoreVersion((version['revision'] as num).toInt()),
          child: const Text('استعادة'),
        ),
      ))),
    ],
  ]));

  Widget _approvalPanel() => Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
    const Text('الاعتماد والنشر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _studioPurple)),
    const SizedBox(height: 8),
    Card(child: ListTile(
      leading: const Icon(Icons.verified_outlined, color: _studioPurple),
      title: Text('الحالة الحالية: ${_statusLabel(_remoteStatus)}'),
      subtitle: Text('الإصدار المركزي: $_remoteRevision • الإصدار المختبر: ${_testedRevision ?? 'لم يُختبر'}'),
    )),
    if (_dirty) const ListTile(leading: Icon(Icons.warning_amber, color: Colors.orange), title: Text('هناك تعديلات محلية غير محفوظة مركزياً.')),
    if (_lastTestReport != null) Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Text(_lastTestReport!))),
    ),
    Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton.icon(onPressed: _busy ? null : _saveCloud, icon: const Icon(Icons.cloud_upload), label: const Text('حفظ مركزي')),
      OutlinedButton.icon(onPressed: _busy ? null : _runTests, icon: const Icon(Icons.fact_check), label: const Text('اختبار الإصدار الحالي')),
      FilledButton.icon(
        onPressed: _busy || _remoteStatus == 'published' ? null : _approveDesign,
        icon: const Icon(Icons.verified),
        label: const Text('اعتماد التصميم'),
      ),
      FilledButton.icon(
        onPressed: _busy || _remoteStatus != 'approved' ? null : _publishDesign,
        icon: const Icon(Icons.publish),
        label: const Text('نشر التصميم'),
      ),
    ]),
    const SizedBox(height: 10),
    const Text('النشر المركزي يغيّر حالة التصميم في قاعدة البيانات فقط. لا يتم استبدال شاشة ERP قائمة تلقائياً قبل اكتمال مراجعة توافق المكونات والصلاحيات وتوصيل مسار العرض المقصود.'),
  ]));

  Widget _statusBar() => Container(
    height: 30,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(children: [
      Icon(Icons.circle, size: 8, color: _dirty ? Colors.orange : Colors.green),
      const SizedBox(width: 5),
      Text(
        _busy ? 'جارٍ التنفيذ...' : '${_dirty ? 'تعديلات غير محفوظة مركزياً' : 'متزامن'} • ${_doc.nodes.length} مكون • ${_statusLabel(_remoteStatus)}',
        style: const TextStyle(fontSize: 11),
      ),
      const Spacer(),
      Text('Schema v${_doc.schemaVersion}', style: const TextStyle(fontSize: 11)),
    ]),
  );

  Widget _command(String label, IconData icon, VoidCallback action) => OutlinedButton.icon(
    onPressed: _busy ? null : action,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: _studioPurple,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
  );

  String _statusLabel(String status) {
    switch (status) {
      case 'review': return 'قيد المراجعة';
      case 'approved': return 'معتمد';
      case 'published': return 'منشور';
      case 'archived': return 'مؤرشف';
      default: return 'مسودة';
    }
  }
}

extension _SetNullableAdd<T> on Set<T> {
  void addIfNotNull(T? value) {
    if (value != null) add(value);
  }
}
