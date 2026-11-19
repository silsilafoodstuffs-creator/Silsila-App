
import 'package:file_picker/file_picker.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_center_toast.dart';

const _brandPurple = Color(0xFF3E007D);
const _brandCanvas = Color(0xFFF7F5FA);
const _brandBorder = Color(0xFFE8E1EF);

class ErpBrandsTab extends StatefulWidget {
  const ErpBrandsTab({super.key, required this.companyId, this.showGroupsOnly = false});
  final String companyId;
  final bool showGroupsOnly;

  @override
  State<ErpBrandsTab> createState() => _ErpBrandsTabState();
}

class _ErpBrandsTabState extends State<ErpBrandsTab> {
  final _search = TextEditingController();
  List<Map<String,dynamic>> _rows = [];
  List<Map<String,dynamic>> _groups = [];
  List<Map<String,dynamic>> _activities = [];
  bool _showGroups = false;
  String? _selectedId;
  bool _loading = false;
  bool _saving = false;
  bool _gridEditing = false;
  String? _gridEditingOnlyId;
  String? _error;
  final Map<String, TextEditingController> _gridNameControllers = <String, TextEditingController>{};
  final Map<String, TextEditingController> _gridEnglishControllers = <String, TextEditingController>{};
  String _viewMode = 'tree';
  final Set<String> _expandedGroups = <String>{};

  SupabaseClient get _db => Supabase.instance.client;
  String _s(dynamic value) => (value ?? '').toString();

  @override
  void initState() {
    super.initState();
    _showGroups = widget.showGroupsOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _gridNameControllers.values) { controller.dispose(); }
    for (final controller in _gridEnglishControllers.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.companyId.trim().isEmpty) {
      setState(() => _error = 'لا توجد شركة نشطة لعرض البراندات.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _db.from('erp_brands')
        .select('id,brand_code,brand_name,brand_name_en,brand_group,brand_group_id,display_order,is_active,is_system,logo_data,logo_mime_type,activity_code')
        .eq('company_id', widget.companyId.trim())
        .order('brand_code');
      final groups = await _db.from('erp_brand_groups').select('id,group_code,group_name,is_active,show_in_app').eq('company_id', widget.companyId.trim()).order('group_code');
      // The activity directory is auxiliary metadata. A missing or restricted
      // activity_types table must never hide the brands/groups catalog.
      List<Map<String,dynamic>> activities = <Map<String,dynamic>>[];
      try {
        final activityRows = await _db.from('activity_types')
            .select('code,name')
            .eq('is_active', true)
            .order('sort_order')
            .order('code');
        activities = List<Map<String,dynamic>>.from(activityRows);
      } catch (_) {
        activities = const [
          {'code':'ACT001','name':'مواد غذائية'},
          {'code':'ACT002','name':'لوازم بناء'},
          {'code':'ACT003','name':'ملابس واكسسوارات'},
          {'code':'ACT004','name':'أجهزة وإلكترونيات'},
          {'code':'ACT005','name':'سيارات ومعدات'},
          {'code':'ACT006','name':'خدمات شحن ونقل'},
          {'code':'ACT007','name':'أثاث وديكورات'},
        ];
      }
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _groups = List<Map<String,dynamic>>.from(groups);
        _rows = List<Map<String,dynamic>>.from(rows);
        _syncGridNameControllers();
        if (!_rows.any((row) => _s(row['id']) == _selectedId)) {
          _selectedId = _rows.isEmpty ? null : _s(_rows.first['id']);
        }
        _expandedGroups.addAll(_groupNames);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل البراندات/الماركات: $error'; });
    }
  }

  void _syncGridNameControllers() {
    final keep = _rows.map((r) => _s(r['id'])).toSet();
    for (final id in _gridNameControllers.keys.where((id) => !keep.contains(id)).toList()) { _gridNameControllers.remove(id)?.dispose(); }
    for (final id in _gridEnglishControllers.keys.where((id) => !keep.contains(id)).toList()) { _gridEnglishControllers.remove(id)?.dispose(); }
    for (final row in _rows) {
      final id = _s(row['id']);
      final ar = _gridNameControllers.putIfAbsent(id, () => TextEditingController());
      final en = _gridEnglishControllers.putIfAbsent(id, () => TextEditingController());
      if (!_gridEditing) { ar.text = _s(row['brand_name']); en.text = _s(row['brand_name_en']); }
    }
  }

  Future<void> _saveGridNames({String? onlyId}) async {
    if (_saving) return;
    final targetId = onlyId ?? _gridEditingOnlyId;
    final targets = _rows.where((row) {
      final id = _s(row['id']);
      if (row['is_system'] == true || (targetId != null && id != targetId)) return false;
      return _gridNameControllers[id]!.text.trim() != _s(row['brand_name']).trim() ||
          _gridEnglishControllers[id]!.text.trim() != _s(row['brand_name_en']).trim();
    }).toList();
    if (targets.isEmpty) {
      ErpCenterToast.show(context, 'لا توجد أسماء تم تعديلها.');
      return;
    }
    for (final row in targets) {
      if (_gridNameControllers[_s(row['id'])]!.text.trim().isEmpty) {
        ErpCenterToast.show(context, 'اسم البراند بالعربية لا يمكن أن يكون فارغًا.', isError: true);
        return;
      }
    }
    setState(() { _saving = true; _error = null; });
    try {
      final payload = targets.map((row) {
        final id = _s(row['id']);
        return <String,dynamic>{
          'id': id,
          'brand_name': _gridNameControllers[id]!.text.trim(),
          'brand_name_en': _gridEnglishControllers[id]!.text.trim(),
        };
      }).toList();
      await _db.rpc('erp_update_brand_names_batch', params: {
        'p_company_id': widget.companyId.trim(),
        'p_rows': payload,
      });
      if (!mounted) return;
      setState(() { _gridEditing = false; _gridEditingOnlyId = null; });
      await _load();
      if (mounted) ErpCenterToast.show(context, targets.length == 1
          ? 'تم حفظ اسم البراند بنجاح مع الاحتفاظ بكوده وربط أصنافه.'
          : 'تم حفظ أسماء البراندات المحددة دفعة واحدة مع الاحتفاظ بالأكواد والارتباطات.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, _friendlySaveError(error), isError: true);
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String,dynamic>> get _visibleRows {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return _rows;
    return _rows.where((row) =>
      _s(row['brand_code']).toLowerCase().contains(term) ||
      _s(row['brand_name']).toLowerCase().contains(term) ||
      _s(row['brand_name_en']).toLowerCase().contains(term) ||
      _s(row['brand_group']).toLowerCase().contains(term)
    ).toList();
  }

  String _friendlySaveError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '23505') return 'اسم البراند العربي مستخدم بالفعل. اختر اسمًا مختلفًا.';
      if (code == '22023') return 'راجع أسماء البراندات؛ الاسم العربي مطلوب ولا يمكن تكراره داخل نفس الشركة.';
      if (code == 'P0002') return 'البراند المحدد غير متاح للتعديل أو أنه سجل محمي. لم يتم حفظ أي تغيير.';
      if (code == '23503') return 'تعذر الحفظ: يوجد ارتباط ببيانات أخرى غير متوافقة. لم يتم تغيير كود البراند أو ارتباطات الأصناف.';
      if (code == '42501' || code == 'PGRST301') return 'تعذر الحفظ: صلاحية تعديل البراند غير متاحة لهذا الحساب.';
      if (code == '23514' || code == '23502') return 'البيانات غير مكتملة أو لا تطابق قواعد التحقق. راجع اسم البراند.';
      if (code == 'PGRST116') return 'لم يتم العثور على سجل البراند المطلوب أو لا يمكن الوصول إليه.';
      return 'تعذر حفظ البراند بسبب مشكلة في قاعدة البيانات. لم يتم عرض تفاصيل تقنية أو أكواد للمستخدم.';
    }
    return 'تعذر حفظ البراند. حاول مرة أخرى.';
  }
  Future<void> _edit({Map<String,dynamic>? row}) async {
    if (row?['is_system'] == true) {
      ErpCenterToast.show(context, 'السجل الافتراضي «بدون علامة تجارية» محمي من التعديل.', isError: true);
      return;
    }
    final name = TextEditingController(text: _s(row?['brand_name']));
    final english = TextEditingController(text: _s(row?['brand_name_en']));
    var activityCode = _s(row?['activity_code']).isEmpty
        ? 'ACT001'
        : _s(row?['activity_code']);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(row == null ? 'إضافة براند/ماركة' : 'تعديل البراند/الماركة'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم البراند/الماركة بالعربية *'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم البراند.' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: english,
                    decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: activityCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع النشاط المرتبط بالبراند *',
                    ),
                    items: _activities.map((activity) => DropdownMenuItem<String>(
                      value: _s(activity['code']),
                      child: Text('${_s(activity['name'])} — ${_s(activity['code'])}'),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) activityCode = value;
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'اختر نوع النشاط.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (formKey.currentState?.validate() == true) Navigator.pop(dialogContext, true);
            }, child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (result != true) {
      name.dispose();
      english.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String,dynamic>{
        'brand_name': name.text.trim(),
        'brand_name_en': english.text.trim().isEmpty ? null : english.text.trim(),
        if (row == null || activityCode != _s(row['activity_code'])) 'activity_code': activityCode,
      };
      if (row == null) {
        final inserted = await _db.from('erp_brands')
          .insert({'company_id':widget.companyId.trim(), ...payload})
          .select('id,brand_code,brand_name,brand_name_en,is_active,is_system')
          .single();
        if (mounted) _selectedId = _s(inserted['id']);
      } else {
        await _db.rpc('erp_update_brand_names_batch', params: {
          'p_company_id': widget.companyId.trim(),
          'p_rows': [
            {
              'id': _s(row['id']),
              'brand_name': name.text.trim(),
              'brand_name_en': english.text.trim(),
              'activity_code': activityCode,
            },
          ],
        });
      }
      await _load();
      if (mounted) ErpCenterToast.show(context, row == null ? 'تمت إضافة البراند وتوليد كوده.' : 'تم تعديل بيانات البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, _friendlySaveError(error), isError: true);
    } finally {
      name.dispose();
      english.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Uint8List? _logoBytes(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final hex = raw.startsWith(r'\x') ? raw.substring(2) : raw;
    if (hex.isEmpty || hex.length.isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ));
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadLogo([Map<String,dynamic>? target]) async {
    final row = target ?? _selectedRow();
    if (row == null) {
      ErpCenterToast.show(context, 'اختر براندًا أولًا.', isError: true);
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ErpCenterToast.show(context, 'تعذر قراءة ملف الشعار.', isError: true);
      return;
    }
    if (bytes.length > 256 * 1024) {
      ErpCenterToast.show(context, 'الحد الأقصى لحجم شعار البراند 256 كيلوبايت.', isError: true);
      return;
    }
    final ext = file.extension?.toLowerCase() ?? '';
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => '',
    };
    if (mime.isEmpty) {
      ErpCenterToast.show(context, 'الصيغ المدعومة للشعار JPG وPNG وWEBP وGIF.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final hex = r'\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _db.from('erp_brands').update({
        'logo_data': hex,
        'logo_mime_type': mime,
      }).eq('id', _s(row['id'])).eq('company_id', widget.companyId.trim()).select('id').single();
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم حفظ شعار البراند بنجاح.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حفظ شعار البراند: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _bulkImportLogos() async {
    if (widget.companyId.trim().isEmpty || _saving) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image, allowMultiple: true, withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final files = picked.files.where((file) =>
      file.bytes != null && file.bytes!.isNotEmpty &&
      const {'jpg','jpeg','png','webp','gif'}.contains(file.extension?.toLowerCase())
    ).toList()..sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (files.isEmpty) {
      if (mounted) ErpCenterToast.show(context, 'لم يتم اختيار صور مدعومة.', isError: true);
      return;
    }
    final oversized = files.where((file) => file.bytes!.length > 256 * 1024).length;
    if (oversized > 0) {
      if (mounted) ErpCenterToast.show(context, 'تم إيقاف الاستيراد: يوجد $oversized ملف يتجاوز 256 كيلوبايت.', isError: true);
      return;
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    setState(() { _saving = true; _error = null; });
    var imported = 0;
    try {
      for (var start = 0; start < files.length; start += 10) {
        final end = (start + 10 < files.length) ? start + 10 : files.length;
        final batch = <Map<String,dynamic>>[];
        for (var index = start; index < end; index++) {
          final file = files[index];
          final sequence = (index + 1).toString().padLeft(3, '0');
          final ext = file.extension!.toLowerCase();
          final mime = switch (ext) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            'gif' => 'image/gif',
            _ => '',
          };
          final bytes = file.bytes!;
          final hex = r'\x' + bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          batch.add({
            'company_id': widget.companyId.trim(),
            'brand_name': 'مراجعة شعار $sequence - $stamp',
            'brand_name_en': 'Review Logo $sequence - $stamp',
            'brand_group': 'شعارات مستوردة للمراجعة',
            'logo_data': hex,
            'logo_mime_type': mime,
            'display_order': 2000 + index,
          });
        }
        await _db.from('erp_brands').insert(batch);
        imported += batch.length;
      }
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم استيراد $imported شعارًا كسجلات مستقلة بأكواد تلقائية.');
    } catch (error) {
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم استيراد $imported من أصل ${files.length} صورة قبل حدوث خطأ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(Map<String,dynamic> row) async {
    if (row['is_system'] == true) return;
    try {
      await _db.from('erp_brands').update({'is_active':row['is_active'] != true})
        .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim())
        .select('id').single();
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم تحديث حالة البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر تحديث حالة البراند: $error', isError: true);
    }
  }

  Map<String,dynamic>? _selectedRow() {
    final matches = _rows.where((item) => _s(item['id']) == _selectedId);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _delete() async {
    final row = _selectedRow();
    if (row == null) {
      ErpCenterToast.show(context, 'اختر براندًا أولًا.', isError: true);
      return;
    }
    if (row['is_system'] == true) {
      ErpCenterToast.show(context, 'لا يمكن حذف سجل «بدون علامة تجارية».', isError: true);
      return;
    }
    final deleted = await _db.from('erp_brands').delete()
      .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim())
      .select('id');
    if (deleted.isEmpty) throw StateError('لم يتم حذف البراند المحدد.');
    await _load();
  }



  String _groupKey(Map<String,dynamic> row) {
    final id = _s(row['brand_group_id']);
    final matches = _groups.where((g) => _s(g['id']) == id);
    if (matches.isNotEmpty) return _s(matches.first['group_name']);
    final legacy = _s(row['brand_group']).trim();
    return legacy.isEmpty ? 'بدون مجموعة' : legacy;
  }

  Future<void> _addGroup() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(title: const Text('إضافة مجموعة براندات'), content: SizedBox(width: 360,
        child: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المجموعة *'))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx,name.text.trim().isNotEmpty), child: const Text('حفظ'))])));
    if (ok != true) { name.dispose(); return; }
    setState(() => _saving = true);
    try {
      final inserted = await _db.from('erp_brand_groups').insert({'company_id':widget.companyId.trim(),'group_name':name.text.trim()})
        .select('id,group_code,group_name,is_active').single();
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم إنشاء المجموعة بالكود ${_s(inserted['group_code'])}.');
    } catch (e) { if (mounted) ErpCenterToast.show(context, 'تعذر إنشاء المجموعة: $e', isError: true); }
    finally { name.dispose(); if (mounted) setState(() => _saving = false); }
  }


  Future<void> _openGroupBrandPicker(Map<String,dynamic> group) async {
    if (_saving) return;
    final groupId = _s(group['id']);
    final isUngrouped = groupId.isEmpty;
    final selectedIds = <String>{};
    final search = TextEditingController();
    final available = _rows.where((row) => row['is_system'] != true &&
      (isUngrouped ? _s(row['brand_group_id']).isNotEmpty : _s(row['brand_group_id']) != groupId))
      .toList()..sort(_compareBrandCodes);
    final accepted = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (dialogContext) => Directionality(textDirection: TextDirection.rtl,
        child: StatefulBuilder(builder: (context, setDialogState) {
          final term = search.text.trim().toLowerCase();
          final filtered = available.where((row) => _s(row['brand_code']).toLowerCase().contains(term) ||
            _s(row['brand_name']).toLowerCase().contains(term) ||
            _s(row['brand_name_en']).toLowerCase().contains(term)).toList();
          return AlertDialog(
            title: Text(isUngrouped ? 'إعادة براندات إلى بدون مجموعة' : 'إضافة براندات إلى ${_s(group['group_name'])}'),
            content: SizedBox(width: 900, height: 560, child: Column(children: [
              TextField(controller: search, onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'ابحث بكود البراند أو الاسم العربي أو الإنجليزي',
                  prefixIcon: Icon(Icons.search, color: _brandPurple), isDense: true, border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('البراندات المتاحة: ${filtered.length} • المحدد: ${selectedIds.length}',
                  style: const TextStyle(color: _brandPurple, fontWeight: FontWeight.w800))),
                TextButton(onPressed: filtered.isEmpty ? null : () => setDialogState(() {
                  selectedIds.addAll(filtered.map((row) => _s(row['id'])));
                }), child: const Text('تحديد نتائج البحث')),
                TextButton(onPressed: selectedIds.isEmpty ? null : () => setDialogState(selectedIds.clear),
                  child: const Text('إلغاء التحديد')),
              ]),
              Expanded(child: filtered.isEmpty ? const Center(child: Text('لا توجد براندات متاحة مطابقة للبحث.'))
                : SingleChildScrollView(child: SizedBox(width: 850, child: DataTable2(
                  minWidth: 820, columnSpacing: 10, horizontalMargin: 8, headingRowHeight: 42,
                  dataRowHeight: 48, showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                  columns: const [
                    DataColumn2(label: Text('اختيار'), size: ColumnSize.S, fixedWidth: 76),
                    DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                    DataColumn2(label: Text('كود البراند'), size: ColumnSize.S, fixedWidth: 115),
                    DataColumn2(label: Text('اسم البراند عربي'), size: ColumnSize.L),
                    DataColumn2(label: Text('الاسم الإنجليزي'), size: ColumnSize.L),
                  ],
                  rows: List<DataRow>.generate(filtered.length, (index) {
                    final row = filtered[index], id = _s(filtered[index]['id']);
                    final checked = selectedIds.contains(id);
                    return DataRow(selected: checked, onSelectChanged: (_) => setDialogState(() {
                      if (checked) { selectedIds.remove(id); } else { selectedIds.add(id); }
                    }), cells: [
                      DataCell(Checkbox(shape: const CircleBorder(), value: checked, activeColor: _brandPurple,
                        onChanged: (value) => setDialogState(() {
                          if (value == true) { selectedIds.add(id); } else { selectedIds.remove(id); }
                        }))),
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(_s(row['brand_code']), style: const TextStyle(color: _brandPurple, fontWeight: FontWeight.w900))),
                      DataCell(Text(_s(row['brand_name']))),
                      DataCell(Text(_s(row['brand_name_en']))),
                    ]);
                  }),
                )))),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton.icon(onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.add), label: Text('إضافة المحدد (${selectedIds.length})')),
            ],
          );
        })));
    search.dispose();
    if (accepted != true || selectedIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final ids = selectedIds.toList();
      await _db.from('erp_brands').update({'brand_group_id': isUngrouped ? null : groupId})
        .eq('company_id', widget.companyId.trim()).inFilter('id', ids).select('id');
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم ربط ${ids.length} براند بالمجموعة المحددة بنجاح.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر ربط البراندات بالمجموعة: $error', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _deleteGroup(Map<String,dynamic> group) async {
    final id = _s(group['id']);
    if (id.isEmpty || _saving) return;
    final count = _rows.where((row) => _s(row['brand_group_id']) == id).length;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        title: const Text('حذف مجموعة البراندات'),
        content: Text('سيتم حذف المجموعة «${_s(group['group_name'])}». عدد البراندات المرتبطة بها: $count. ستنتقل هذه البراندات تلقائيًا إلى «بدون مجموعة» مع الاحتفاظ ببياناتها وأكوادها. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.delete_outline),
            label: const Text('حذف المجموعة')),
        ],
      )));
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _db.from('erp_brand_groups').delete().eq('id', id)
        .eq('company_id', widget.companyId.trim()).select('id').single();
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم حذف المجموعة ونقل برانداتها إلى بدون مجموعة.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حذف المجموعة: $error', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _toggleGroupField(Map<String,dynamic> group, String field) async {
    final id = _s(group['id']);
    if (id.isEmpty || _saving) return;
    final next = group[field] != true;
    setState(() => _saving = true);
    try {
      await _db.from('erp_brand_groups').update({field: next})
        .eq('id', id).eq('company_id', widget.companyId.trim()).select('id').single();
      await _load();
      if (mounted) ErpCenterToast.show(context, field == 'is_active'
        ? (next ? 'تم تنشيط المجموعة.' : 'تم إيقاف المجموعة.')
        : (next ? 'المجموعة ستظهر في التطبيق.' : 'تم إخفاء المجموعة من التطبيق.'));
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر تحديث بيانات المجموعة: $error', isError: true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _editGroup(Map<String,dynamic> group) async {
    final name = TextEditingController(text:_s(group['group_name']));
    final ok = await showDialog<bool>(context:context,builder:(ctx)=>Directionality(
      textDirection:TextDirection.rtl, child:AlertDialog(title:const Text('تعديل مجموعة البراندات'),
        content:SizedBox(width:360,child:TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المجموعة *'))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,name.text.trim().isNotEmpty),child:const Text('حفظ'))])));
    if(ok!=true){name.dispose();return;}
    try {
      await _db.from('erp_brand_groups').update({'group_name':name.text.trim()})
        .eq('id',_s(group['id'])).eq('company_id',widget.companyId.trim()).select('id').single();
      await _load();
      if(mounted) ErpCenterToast.show(context,'تم تعديل اسم المجموعة.');
    } catch(e){if(mounted) ErpCenterToast.show(context,'تعذر تعديل المجموعة: $e',isError:true);}
    finally{name.dispose();}
  }

  Future<void> _toggleGroup(Map<String,dynamic> group) async {
    try {
      await _db.from('erp_brand_groups').update({'is_active':group['is_active']!=true})
        .eq('id',_s(group['id'])).eq('company_id',widget.companyId.trim()).select('id').single();
      await _load();
    } catch(e){if(mounted) ErpCenterToast.show(context,'تعذر تغيير حالة المجموعة: $e',isError:true);}
  }

  Future<void> _assignGroup(Map<String,dynamic> row, String? groupId) async {
    try {
      await _db.from('erp_brands').update({'brand_group_id':groupId})
        .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim()).select('id').single();
      await _load();
    } catch (e) { if (mounted) ErpCenterToast.show(context, 'تعذر تغيير مجموعة البراند: $e', isError: true); }
  }

  List<String> get _groupNames {
    final names = _rows.map(_groupKey).toSet().toList();
    names.sort((a,b) {
      if (a == 'بدون مجموعة') return 1;
      if (b == 'بدون مجموعة') return -1;
      return a.compareTo(b);
    });
    return names;
  }

  int _brandCodeNumber(Map<String,dynamic> row) =>
      int.tryParse(_s(row['brand_code']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int _compareBrandCodes(Map<String,dynamic> a, Map<String,dynamic> b) {
    final numeric = _brandCodeNumber(a).compareTo(_brandCodeNumber(b));
    return numeric != 0 ? numeric : _s(a['brand_code']).compareTo(_s(b['brand_code']));
  }

  List<Map<String,dynamic>> _rowsInGroup(String group) {
    return _visibleRows.where((row) => _groupKey(row) == group).toList()
      ..sort(_compareBrandCodes);
  }

  Widget _logoPreview(Map<String,dynamic> row, {double size = 48}) {
    final bytes = _logoBytes(row['logo_data']);
    return Container(
      width: size, height: size, alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFD8CBE7)),
      ),
      child: bytes != null && bytes.isNotEmpty
        ? Image.memory(bytes, fit: BoxFit.contain, width: size, height: size,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.black38))
        : const Icon(Icons.storefront_outlined, color: Color(0xFF9A86B5), size: 25),
    );
  }

  Future<void> _removeLogo(Map<String,dynamic> row) async {
    if (row['is_system'] == true) return;
    setState(() => _saving = true);
    try {
      await _db.from('erp_brands').update({
        'logo_data': null, 'logo_mime_type': null,
      }).eq('id', _s(row['id']))
        .eq('company_id', widget.companyId.trim()).select('id').single();
      await _load();
      if (mounted) ErpCenterToast.show(context, 'تم حذف شعار البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حذف الشعار: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _treeBrandRow(Map<String,dynamic> row) {
    final id = _s(row['id']);
    final selected = _selectedId == id;
    final system = row['is_system'] == true;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 18, bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFF0E7FA) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedId = id),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? _brandPurple : _brandBorder),
            ),
            child: Row(children: [
              const SizedBox(width: 34, child: Icon(Icons.subdirectory_arrow_left, color: _brandPurple, size: 18)),
              SizedBox(width: 105, child: Text(_s(row['brand_code']), overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple, fontSize: 12))),
              Expanded(flex: 3, child: Text(_s(row['brand_name']), overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text(_s(row['brand_name_en']), overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54))),
              Checkbox(shape: const CircleBorder(), value: row['is_active'] == true,
                activeColor: _brandPurple, visualDensity: VisualDensity.compact,
                onChanged: system ? null : (_) => _toggle(row)),
              const SizedBox(width: 6),
              _logoPreview(row, size: 44),
              IconButton(tooltip: 'اختيار/تغيير الشعار', visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _uploadLogo(row),
                icon: const Icon(Icons.photo_library_outlined, color: _brandPurple)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _treeGroup(String group) {
    final children = _rowsInGroup(group);
    final expanded = _expandedGroups.contains(group);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE1F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _brandBorder),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            if (expanded) { _expandedGroups.remove(group); }
            else { _expandedGroups.add(group); }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              Icon(expanded ? Icons.keyboard_arrow_down : Icons.chevron_left, color: _brandPurple),
              const Icon(Icons.folder_outlined, color: _brandPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(group == 'بدون مجموعة' ? 'براندات بدون مجموعة' : group,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple))),
              Text('${children.length} براند',
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
            child: Column(children: children.map(_treeBrandRow).toList()),
          ),
      ]),
    );
  }

  Widget _treeHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(children: [
        const SizedBox(width: 34),
        const SizedBox(width: 105, child: Text('كود البراند', style: TextStyle(fontWeight: FontWeight.w800))),
        const Expanded(flex: 3, child: Text('اسم البراند عربي', style: TextStyle(fontWeight: FontWeight.w800))),
        const Expanded(flex: 2, child: Text('الاسم الإنجليزي', style: TextStyle(fontWeight: FontWeight.w800))),
        const Text('نشط', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        const Text('الصورة', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 48),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows.toList()..sort(_compareBrandCodes);
    final selected = _selectedRow();
    final visibleGroups = rows.map(_groupKey).toSet().toList()
      ..sort((a,b) {
        if (a == 'بدون مجموعة') return 1;
        if (b == 'بدون مجموعة') return -1;
        return a.compareTo(b);
      });
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _brandCanvas,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ErpQuickTaskButton(label:'تحديث', icon:Icons.refresh_rounded, onPressed:_loading || _saving ? null : _load),
                ErpQuickTaskButton(label:'عرض شجرة', icon:Icons.account_tree_outlined, onPressed:() => setState(() => _viewMode = 'tree')),
                ErpQuickTaskButton(label:'عرض جدول', icon:Icons.table_rows_outlined, onPressed:() => setState(() => _viewMode = 'grid')),
                ErpQuickTaskButton(label:'إضافة جديد', icon:Icons.add_circle_outline, onPressed:_saving ? null : () => _edit()),
                ErpQuickTaskButton(label:'تعديل المحدد', icon:Icons.edit_outlined, onPressed:_saving ? null : () {
                  if (_viewMode == 'grid') {
                    if (selected == null || selected['is_system'] == true) { ErpCenterToast.show(context, 'حدد براندًا عاديًا من الجدول أولًا.', isError:true); return; }
                    setState(() { _gridEditing = true; _gridEditingOnlyId = _s(selected['id']); });
                    _syncGridNameControllers();
                  } else if (selected != null && selected['is_system'] != true) { _edit(row:selected); }
                }),
                if (_viewMode == 'grid') ErpQuickTaskButton(label:'تعديل الكل', icon:Icons.edit_note_outlined, onPressed:_saving ? null : () {
                  setState(() { _gridEditing = true; _gridEditingOnlyId = null; });
                  _syncGridNameControllers();
                }),
                if (_viewMode == 'grid' && _gridEditing) ...[
                  ErpQuickTaskButton(label:'حفظ التعديلات', icon:Icons.save_outlined, onPressed:_saving ? null : () => _saveGridNames(onlyId:_gridEditingOnlyId)),
                  ErpQuickTaskButton(label:'إلغاء التعديل', icon:Icons.close, onPressed:_saving ? null : () {
                    setState(() { _gridEditing = false; _gridEditingOnlyId = null; });
                    _syncGridNameControllers();
                  }),
                ],
                ErpQuickTaskButton(label:'شعار البراند', icon:Icons.image_outlined, onPressed:_saving || selected == null ? null : () => _uploadLogo(selected)),
                ErpQuickTaskButton(label:'استيراد شعارات متعددة', icon:Icons.collections_outlined, onPressed:_saving ? null : _bulkImportLogos),
                ErpQuickTaskButton(label:'حذف', icon:Icons.delete_outline, onPressed:_saving || selected == null || selected['is_system'] == true ? null : _delete),
              ]),
            ),
          ),
          if (_showGroups) ...[
            Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 4), child: Row(children: [
              Expanded(child: Text('مجموعات البراندات: ${_groups.length} • إجمالي البراندات: ${_rows.length}',
                style: const TextStyle(color: _brandPurple, fontWeight: FontWeight.w800))),
              FilledButton.icon(onPressed: _saving ? null : _addGroup,
                icon: const Icon(Icons.add), label: const Text('إضافة مجموعة جديدة')),
            ])),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: DataTable2(
                  minWidth: 1120, columnSpacing: 10, horizontalMargin: 8,
                  headingRowHeight: 44, dataRowHeight: 54, showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                  columns: const [
                    DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                    DataColumn2(label: Text('كود مجموعة البراند'), size: ColumnSize.M, fixedWidth: 175),
                    DataColumn2(label: Text('اسم المجموعة'), size: ColumnSize.L),
                    DataColumn2(label: Text('عدد البراندات'), size: ColumnSize.S, fixedWidth: 115),
                    DataColumn2(label: Text('نشط أو لا'), size: ColumnSize.S, fixedWidth: 95),
                    DataColumn2(label: Text('يظهر في التطبيق أو لا'), size: ColumnSize.M, fixedWidth: 165),
                    DataColumn2(label: Text('إضافة / حذف'), size: ColumnSize.S, fixedWidth: 130),
                  ],
                  rows: [
                    DataRow(color: WidgetStateProperty.all(const Color(0xFFEDE1F8)), cells: [
                      const DataCell(Text('1', style: TextStyle(fontWeight: FontWeight.w900))),
                      const DataCell(Text('—', style: TextStyle(fontWeight: FontWeight.w900, color: _brandPurple))),
                      const DataCell(Text('بدون مجموعة', style: TextStyle(fontWeight: FontWeight.w900, color: _brandPurple))),
                      DataCell(Text('${_rows.where((row) => _s(row['brand_group_id']).isEmpty && _s(row['brand_group']).trim().isEmpty).length}')),
                      const DataCell(Text('—')), const DataCell(Text('—')),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'إعادة براندات إلى بدون مجموعة',
                          onPressed: _saving ? null : () => _openGroupBrandPicker(const {'id': '', 'group_name': 'بدون مجموعة'}),
                          icon: const Icon(Icons.add_circle, color: _brandPurple)),
                        IconButton(tooltip: 'المجموعة الافتراضية لا تُحذف', onPressed: null,
                          icon: const Icon(Icons.delete, color: Colors.redAccent)),
                      ])),
                    ]),
                    ...(() {
                      final ordered = _groups.toList()..sort((a, b) {
                        final an = int.tryParse(_s(a['group_code']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        final bn = int.tryParse(_s(b['group_code']).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        return an.compareTo(bn);
                      });
                      return ordered.asMap().entries.map((entry) {
                        final index = entry.key + 2, group = entry.value, id = _s(group['id']);
                        final count = _rows.where((row) => _s(row['brand_group_id']) == id).length;
                        return DataRow(color: WidgetStateProperty.all(index.isEven ? Colors.white : const Color(0xFFFCFAFE)),
                          cells: [
                            DataCell(Text('$index')),
                            DataCell(Text(_s(group['group_code']), style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple))),
                            DataCell(Text(_s(group['group_name']), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text('$count')),
                            DataCell(Checkbox(shape: const CircleBorder(), value: group['is_active'] == true,
                              activeColor: _brandPurple, onChanged: _saving ? null : (_) => _toggleGroupField(group, 'is_active'))),
                            DataCell(Checkbox(shape: const CircleBorder(), value: group['show_in_app'] == true,
                              activeColor: const Color(0xFFFFA015), onChanged: _saving ? null : (_) => _toggleGroupField(group, 'show_in_app'))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(tooltip: 'إضافة براندات للمجموعة',
                                onPressed: _saving ? null : () => _openGroupBrandPicker(group),
                                icon: const Icon(Icons.add_circle, color: _brandPurple)),
                              IconButton(tooltip: 'حذف المجموعة', onPressed: _saving ? null : () => _deleteGroup(group),
                                icon: const Icon(Icons.delete, color: Colors.red)),
                            ])),
                          ]);
                      }).toList();
                    })(),
                  ],
                )))),
          ]          ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12,7,12,3),
            child: TextField(
              controller:_search,
              onChanged:(_) => setState(() {}),
              decoration: InputDecoration(
                labelText:'ابحث بكود البراند أو اسمه أو المجموعة',
                prefixIcon:const Icon(Icons.search,color:_brandPurple),
                suffixIcon:_search.text.isEmpty ? null : IconButton(
                  onPressed:() { _search.clear(); setState(() {}); },
                  icon:const Icon(Icons.clear),
                ),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                isDense:true,
              ),
            ),
          ),
          if (_error != null)
            Padding(padding:const EdgeInsets.all(7), child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:12))),
          Padding(
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),
            child:Row(children:[
              Expanded(child:Text('عدد البراندات/الماركات: ${rows.length}',
                style:const TextStyle(color:_brandPurple,fontWeight:FontWeight.w800))),
              if (_viewMode == 'tree') ...[
                TextButton.icon(
                  onPressed:_loading || visibleGroups.isEmpty ? null : () => setState(() => _expandedGroups.addAll(visibleGroups)),
                  icon:const Icon(Icons.unfold_more,size:18), label:const Text('فتح الكل')),
                TextButton.icon(
                  onPressed:_loading ? null : () => setState(() => _expandedGroups.clear()),
                  icon:const Icon(Icons.unfold_less,size:18), label:const Text('طي الكل')),
              ],
            ]),
          ),
          if (_viewMode == 'tree') _treeHeader(),
          Expanded(
            child:_loading
              ? const Center(child:CircularProgressIndicator())
              : rows.isEmpty
                ? const Center(child:Text('لا توجد براندات مطابقة للبحث.'))
                : _viewMode == 'tree'
                  ? ListView(
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                      children:visibleGroups.map(_treeGroup).toList(),
                    )
                  : DataTable2(
                      fixedTopRows: 1,
                      minWidth: 1040,
                      columnSpacing: 8,
                      horizontalMargin: 8,
                      headingRowHeight: 42,
                      dataRowHeight: 60,
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                      columns: const [
                        DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                        DataColumn2(label: Text('كود البراند'), size: ColumnSize.S, fixedWidth: 110),
                        DataColumn2(label: Text('اسم البراند عربي'), size: ColumnSize.L, fixedWidth: 220),
                        DataColumn2(label: Text('الاسم الإنجليزي'), size: ColumnSize.L, fixedWidth: 190),
                        DataColumn2(label: Text('الصورة'), size: ColumnSize.S, fixedWidth: 115),
                        DataColumn2(label: Text('المجموعة'), size: ColumnSize.M, fixedWidth: 190),
                        DataColumn2(label: Text('نشط'), size: ColumnSize.S, fixedWidth: 70),
                      ],
                      rows: List<DataRow>.generate(rows.length, (index) {
                        final row = rows[index];
                        final id = _s(row['id']);
                        final system = row['is_system'] == true;
                        final ar = _gridNameControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['brand_name'])));
                        final en = _gridEnglishControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['brand_name_en'])));
                        return DataRow(
                          color: WidgetStateProperty.all(system ? const Color(0xFFEDE1F8) : Colors.white),
                          cells: [
                            DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Text(_s(row['brand_code']), style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple)), onTap: () => setState(() => _selectedId = id)),
                            DataCell(SizedBox(width: 210, child: _gridEditing && (_gridEditingOnlyId == null || _gridEditingOnlyId == id) && !system
                              ? Focus(
                                  onKeyEvent: (_, event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) { FocusScope.of(context).nextFocus(); return KeyEventResult.handled; }
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) { FocusScope.of(context).previousFocus(); return KeyEventResult.handled; }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(controller: ar, enabled: !_saving, textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(isDense:true, contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8), border:OutlineInputBorder(), hintText:'اسم البراند بالعربية'),
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                                )
                              : Text(_s(row['brand_name']))), onTap: !system && !_gridEditing
                              ? () => setState(() {
                                  _selectedId = id;
                                  _gridEditing = true;
                                  _gridEditingOnlyId = id;
                                })
                              : null),
                            DataCell(SizedBox(width: 180, child: _gridEditing && (_gridEditingOnlyId == null || _gridEditingOnlyId == id) && !system
                              ? Focus(
                                  onKeyEvent: (_, event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) { FocusScope.of(context).nextFocus(); return KeyEventResult.handled; }
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) { FocusScope.of(context).previousFocus(); return KeyEventResult.handled; }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(controller: en, enabled: !_saving, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(isDense:true, contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8), border:OutlineInputBorder(), hintText:'Brand name'),
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                                )
                              : Text(_s(row['brand_name_en'])))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              _logoPreview(row, size: 46),
                              const SizedBox(width: 4),
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(tooltip:'تعديل صورة البراند', visualDensity:VisualDensity.compact, padding:EdgeInsets.zero,
                                  constraints:const BoxConstraints.tightFor(width:30,height:25), onPressed:_saving ? null : () => _uploadLogo(row),
                                  icon:const Icon(Icons.edit_outlined,color:_brandPurple,size:18)),
                                IconButton(tooltip:'حذف صورة البراند', visualDensity:VisualDensity.compact, padding:EdgeInsets.zero,
                                  constraints:const BoxConstraints.tightFor(width:30,height:25), onPressed:_saving || system || _logoBytes(row['logo_data']) == null ? null : () => _removeLogo(row),
                                  icon:const Icon(Icons.delete_outline,color:Colors.redAccent,size:18)),
                              ]),
                            ])),
                            DataCell(SizedBox(width: 180, child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _groups.any((g) => _s(g['id']) == _s(row['brand_group_id'])) ? _s(row['brand_group_id']) : null,
                              hint: const Text('بدون مجموعة'),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('بدون مجموعة')),
                                ..._groups.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text('${_s(g['group_code'])} - ${_s(g['group_name'])}', overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: system ? null : (v) => _assignGroup(row, v),
                            ))),
                            DataCell(Checkbox(shape: const CircleBorder(), value: row['is_active'] == true, activeColor: _brandPurple, onChanged: system ? null : (_) => _toggle(row))),
                          ],
                        );
                      }),
                    ),
          ),
          ],
        ],
      ),
    );
  }
}

          Padding(
            padding: const EdgeInsets.fromLTRB(12,7,12,3),
            child: TextField(
              controller:_search,
              onChanged:(_) => setState(() {}),
              decoration: InputDecoration(
                labelText:'ابحث بكود البراند أو اسمه أو المجموعة',
                prefixIcon:const Icon(Icons.search,color:_brandPurple),
                suffixIcon:_search.text.isEmpty ? null : IconButton(
                  onPressed:() { _search.clear(); setState(() {}); },
                  icon:const Icon(Icons.clear),
                ),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                isDense:true,
              ),
            ),
          ),
          if (_error != null)
            Padding(padding:const EdgeInsets.all(7), child:Text(_error!,style:const TextStyle(color:Colors.red,fontSize:12))),
          Padding(
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),
            child:Row(children:[
              Expanded(child:Text('عدد البراندات/الماركات: ${rows.length}',
                style:const TextStyle(color:_brandPurple,fontWeight:FontWeight.w800))),
              if (_viewMode == 'tree') ...[
                TextButton.icon(
                  onPressed:_loading || visibleGroups.isEmpty ? null : () => setState(() => _expandedGroups.addAll(visibleGroups)),
                  icon:const Icon(Icons.unfold_more,size:18), label:const Text('فتح الكل')),
                TextButton.icon(
                  onPressed:_loading ? null : () => setState(() => _expandedGroups.clear()),
                  icon:const Icon(Icons.unfold_less,size:18), label:const Text('طي الكل')),
              ],
            ]),
          ),
          if (_viewMode == 'tree') _treeHeader(),
          Expanded(
            child:_loading
              ? const Center(child:CircularProgressIndicator())
              : rows.isEmpty
                ? const Center(child:Text('لا توجد براندات مطابقة للبحث.'))
                : _viewMode == 'tree'
                  ? ListView(
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                      children:visibleGroups.map(_treeGroup).toList(),
                    )
                  : DataTable2(
                      fixedTopRows: 1,
                      minWidth: 1040,
                      columnSpacing: 8,
                      horizontalMargin: 8,
                      headingRowHeight: 42,
                      dataRowHeight: 60,
                      showCheckboxColumn: false,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                      columns: const [
                        DataColumn2(label: Text('م'), size: ColumnSize.S, fixedWidth: 52),
                        DataColumn2(label: Text('كود البراند'), size: ColumnSize.S, fixedWidth: 110),
                        DataColumn2(label: Text('اسم البراند عربي'), size: ColumnSize.L, fixedWidth: 220),
                        DataColumn2(label: Text('الاسم الإنجليزي'), size: ColumnSize.L, fixedWidth: 190),
                        DataColumn2(label: Text('الصورة'), size: ColumnSize.S, fixedWidth: 115),
                        DataColumn2(label: Text('المجموعة'), size: ColumnSize.M, fixedWidth: 190),
                        DataColumn2(label: Text('نشط'), size: ColumnSize.S, fixedWidth: 70),
                      ],
                      rows: List<DataRow>.generate(rows.length, (index) {
                        final row = rows[index];
                        final id = _s(row['id']);
                        final system = row['is_system'] == true;
                        final ar = _gridNameControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['brand_name'])));
                        final en = _gridEnglishControllers.putIfAbsent(id, () => TextEditingController(text: _s(row['brand_name_en'])));
                        return DataRow(
                          color: WidgetStateProperty.all(system ? const Color(0xFFEDE1F8) : Colors.white),
                          cells: [
                            DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Text(_s(row['brand_code']), style: const TextStyle(fontWeight: FontWeight.w900, color: _brandPurple)), onTap: () => setState(() => _selectedId = id)),
                            DataCell(SizedBox(width: 210, child: _gridEditing && (_gridEditingOnlyId == null || _gridEditingOnlyId == id) && !system
                              ? Focus(
                                  onKeyEvent: (_, event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) { FocusScope.of(context).nextFocus(); return KeyEventResult.handled; }
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) { FocusScope.of(context).previousFocus(); return KeyEventResult.handled; }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(controller: ar, enabled: !_saving, textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(isDense:true, contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8), border:OutlineInputBorder(), hintText:'اسم البراند بالعربية'),
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                                )
                              : Text(_s(row['brand_name']))), onTap: !system && !_gridEditing
                              ? () => setState(() {
                                  _selectedId = id;
                                  _gridEditing = true;
                                  _gridEditingOnlyId = id;
                                })
                              : null),
                            DataCell(SizedBox(width: 180, child: _gridEditing && (_gridEditingOnlyId == null || _gridEditingOnlyId == id) && !system
                              ? Focus(
                                  onKeyEvent: (_, event) {
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) { FocusScope.of(context).nextFocus(); return KeyEventResult.handled; }
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) { FocusScope.of(context).previousFocus(); return KeyEventResult.handled; }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(controller: en, enabled: !_saving, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(isDense:true, contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8), border:OutlineInputBorder(), hintText:'Brand name'),
                                    onSubmitted: (_) => FocusScope.of(context).nextFocus()),
                                )
                              : Text(_s(row['brand_name_en'])))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              _logoPreview(row, size: 46),
                              const SizedBox(width: 4),
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(tooltip:'تعديل صورة البراند', visualDensity:VisualDensity.compact, padding:EdgeInsets.zero,
                                  constraints:const BoxConstraints.tightFor(width:30,height:25), onPressed:_saving ? null : () => _uploadLogo(row),
                                  icon:const Icon(Icons.edit_outlined,color:_brandPurple,size:18)),
                                IconButton(tooltip:'حذف صورة البراند', visualDensity:VisualDensity.compact, padding:EdgeInsets.zero,
                                  constraints:const BoxConstraints.tightFor(width:30,height:25), onPressed:_saving || system || _logoBytes(row['logo_data']) == null ? null : () => _removeLogo(row),
                                  icon:const Icon(Icons.delete_outline,color:Colors.redAccent,size:18)),
                              ]),
                            ])),
                            DataCell(SizedBox(width: 180, child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _groups.any((g) => _s(g['id']) == _s(row['brand_group_id'])) ? _s(row['brand_group_id']) : null,
                              hint: const Text('بدون مجموعة'),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('بدون مجموعة')),
                                ..._groups.map((g) => DropdownMenuItem<String?>(value: _s(g['id']), child: Text('${_s(g['group_code'])} - ${_s(g['group_name'])}', overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: system ? null : (v) => _assignGroup(row, v),
                            ))),
                            DataCell(Checkbox(shape: const CircleBorder(), value: row['is_active'] == true, activeColor: _brandPurple, onChanged: system ? null : (_) => _toggle(row))),
                          ],
                        );
                      }),
                    ),
          ),
          ],
        ],
      ),
    );
  }
}
