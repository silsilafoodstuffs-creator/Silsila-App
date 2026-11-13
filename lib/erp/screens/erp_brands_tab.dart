import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_center_toast.dart';

const _brandPurple = Color(0xFF3E007D);
const _brandCanvas = Color(0xFFF7F5FA);
const _brandBorder = Color(0xFFE8E1EF);

class ErpBrandsTab extends StatefulWidget {
  const ErpBrandsTab({super.key, required this.companyId});
  final String companyId;

  @override
  State<ErpBrandsTab> createState() => _ErpBrandsTabState();
}

class _ErpBrandsTabState extends State<ErpBrandsTab> {
  final _search = TextEditingController();
  List<Map<String,dynamic>> _rows = [];
  List<Map<String,dynamic>> _groups = [];
  bool _showGroups = false;
  String? _selectedId;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String _viewMode = 'tree';
  final Set<String> _expandedGroups = <String>{};

  SupabaseClient get _db => Supabase.instance.client;
  String _s(dynamic value) => (value ?? '').toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
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
        .select('id,brand_code,brand_name,brand_name_en,brand_group,brand_group_id,display_order,is_active,is_system,logo_data,logo_mime_type')
        .eq('company_id', widget.companyId.trim())
        .order('brand_code');
      final groups = await _db.from('erp_brand_groups').select('id,group_code,group_name,is_active').eq('company_id', widget.companyId.trim()).order('group_code');
      if (!mounted) return;
      setState(() {
        _groups = List<Map<String,dynamic>>.from(groups);
        _rows = List<Map<String,dynamic>>.from(rows);
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

  Future<void> _edit({Map<String,dynamic>? row}) async {
    if (row?['is_system'] == true) {
      ErpCenterToast.show(context, 'السجل الافتراضي «بدون علامة تجارية» محمي من التعديل.', isError: true);
      return;
    }
    final name = TextEditingController(text: _s(row?['brand_name']));
    final english = TextEditingController(text: _s(row?['brand_name_en']));
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
      };
      if (row == null) {
        final inserted = await _db.from('erp_brands')
          .insert({'company_id':widget.companyId.trim(), ...payload})
          .select('id,brand_code,brand_name,brand_name_en,is_active,is_system')
          .single();
        if (mounted) _selectedId = _s(inserted['id']);
      } else {
        await _db.from('erp_brands').update(payload)
          .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim())
          .select('id').single();
      }
      await _load();
      if (mounted) ErpCenterToast.show(context, row == null ? 'تمت إضافة البراند وتوليد كوده.' : 'تم تعديل بيانات البراند.');
    } catch (error) {
      if (mounted) ErpCenterToast.show(context, 'تعذر حفظ البراند: $error', isError: true);
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

  List<Map<String,dynamic>> _rowsInGroup(String group) {
    return _visibleRows.where((row) => _groupKey(row) == group).toList()
      ..sort((a,b) => _s(a['brand_code']).compareTo(_s(b['brand_code'])));
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
    final rows = _visibleRows;
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
                ErpQuickTaskButton(label:'مجموعات البراندات', icon:Icons.folder_copy_outlined, onPressed:() => setState(() => _showGroups = true)),
                ErpQuickTaskButton(label:'تحديث', icon:Icons.refresh_rounded, onPressed:_loading || _saving ? null : _load),
                ErpQuickTaskButton(label:'البراندات', icon:Icons.sell_outlined, onPressed:() => setState(() => _showGroups = false)),
                ErpQuickTaskButton(label:'عرض شجرة', icon:Icons.account_tree_outlined, onPressed:() => setState(() => _viewMode = 'tree')),
                ErpQuickTaskButton(label:'عرض جدول', icon:Icons.table_rows_outlined, onPressed:() => setState(() => _viewMode = 'grid')),
                ErpQuickTaskButton(label:'إضافة جديد', icon:Icons.add_circle_outline, onPressed:_saving ? null : () => _edit()),
                ErpQuickTaskButton(label:'تعديل', icon:Icons.edit_outlined, onPressed:_saving || selected == null || selected['is_system'] == true ? null : () => _edit(row:selected)),
                ErpQuickTaskButton(label:'شعار البراند', icon:Icons.image_outlined, onPressed:_saving || selected == null ? null : () => _uploadLogo(selected)),
                ErpQuickTaskButton(label:'استيراد شعارات متعددة', icon:Icons.collections_outlined, onPressed:_saving ? null : _bulkImportLogos),
                ErpQuickTaskButton(label:'حذف', icon:Icons.delete_outline, onPressed:_saving || selected == null || selected['is_system'] == true ? null : _delete),
              ]),
            ),
          ),
          if (_showGroups) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), child: Row(children:[
              Expanded(child:Text('عدد مجموعات البراندات: ${_groups.length}', style:const TextStyle(color:_brandPurple,fontWeight:FontWeight.w800))),
              FilledButton.icon(onPressed:_saving ? null : _addGroup, icon:const Icon(Icons.add), label:const Text('إضافة مجموعة')),
            ])),
            Expanded(child:_loading ? const Center(child:CircularProgressIndicator()) : _groups.isEmpty ? const Center(child:Text('لم تنشئ مجموعات بعد.')) : ListView.builder(
              padding:const EdgeInsets.all(10), itemCount:_groups.length, itemBuilder:(ctx,i) { final g=_groups[i]; final count=_rows.where((r) => _s(r['brand_group_id'])==_s(g['id'])).length;
                return Card(child:ListTile(leading:const Icon(Icons.folder_outlined,color:_brandPurple), title:Text(_s(g['group_name']),style:const TextStyle(fontWeight:FontWeight.bold)), subtitle:Text(_s(g['group_code'])), trailing:Text('$count براند')));
              })),
          ] else ...[
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
                  : SingleChildScrollView(
                      scrollDirection:Axis.horizontal,
                      child:SingleChildScrollView(
                        child:DataTable(
                          headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                          dataRowMinHeight:56,
                          dataRowMaxHeight:64,
                          columns:const [
                            DataColumn(label:Text('كود البراند')),
                            DataColumn(label:Text('اسم البراند عربي')),
                            DataColumn(label:Text('الاسم الإنجليزي')),
                            DataColumn(label:Text('الصورة')),
                            DataColumn(label:Text('المجموعة')),
                            DataColumn(label:Text('نوع السجل')),
                            DataColumn(label:Text('نشط')),
                            DataColumn(label:Text('إدارة الصورة')),
                          ],
                          rows:rows.map((row) {
                            final id = _s(row['id']);
                            final system = row['is_system'] == true;
                            return DataRow(
                              selected:_selectedId == id,
                              onSelectChanged:(_) => setState(() => _selectedId = id),
                              color:WidgetStateProperty.all(system ? const Color(0xFFEDE1F8) : Colors.white),
                              cells:[
                                DataCell(Text(_s(row['brand_code']),style:const TextStyle(fontWeight:FontWeight.w900,color:_brandPurple))),
                                DataCell(SizedBox(width:180,child:Text(_s(row['brand_name'])))),
                                DataCell(SizedBox(width:150,child:Text(_s(row['brand_name_en'])))),
                                DataCell(_logoPreview(row,size:46)),
                                DataCell(SizedBox(width:170, child: DropdownButton<String?>(isExpanded:true, value: _groups.any((g) => _s(g['id']) == _s(row['brand_group_id'])) ? _s(row['brand_group_id']) : null, hint: const Text('بدون مجموعة'), items: [const DropdownMenuItem<String?>(value:null, child:Text('بدون مجموعة')), ..._groups.map((g) => DropdownMenuItem<String?>(value:_s(g['id']), child:Text('${_s(g['group_code'])} - ${_s(g['group_name'])}', overflow:TextOverflow.ellipsis)))], onChanged: system ? null : (v) => _assignGroup(row,v)))),
                                DataCell(Text(system ? 'افتراضي' : 'براند')),
                                DataCell(Checkbox(
                                  shape:const CircleBorder(), value:row['is_active'] == true,
                                  activeColor:_brandPurple, onChanged:system ? null : (_) => _toggle(row))),
                                DataCell(Row(mainAxisSize:MainAxisSize.min,children:[
                                  IconButton(tooltip:'اختيار/تغيير الشعار',onPressed:_saving ? null : () => _uploadLogo(row),
                                    icon:const Icon(Icons.photo_library_outlined,color:_brandPurple)),
                                  IconButton(tooltip:'حذف الشعار',
                                    onPressed:_saving || system || _logoBytes(row['logo_data']) == null ? null : () => _removeLogo(row),
                                    icon:const Icon(Icons.hide_image_outlined,color:Colors.redAccent)),
                                ])),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
          ),
          ],
        ],
      ),
    );
  }
}
