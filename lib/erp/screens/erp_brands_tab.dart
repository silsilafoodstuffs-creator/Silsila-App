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
        .select('id,brand_code,brand_name,brand_name_en,brand_group,display_order,is_active,is_system,logo_data,logo_mime_type')
        .eq('company_id', widget.companyId.trim())
        .order('display_order')
        .order('brand_code');
      if (!mounted) return;
      setState(() {
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
    final group = TextEditingController(text: _s(row?['brand_group']));
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
                  TextFormField(
                    controller: group,
                    decoration: const InputDecoration(labelText: 'المجموعة (إن وجدت)'),
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
      group.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String,dynamic>{
        'brand_name': name.text.trim(),
        'brand_name_en': english.text.trim().isEmpty ? null : english.text.trim(),
        'brand_group': group.text.trim().isEmpty ? null : group.text.trim(),
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
      group.dispose();
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
    final group = _s(row['brand_group']).trim();
    return group.isEmpty ? 'بدون مجموعة' : group;
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
      ..sort((a,b) {
        final byOrder = (a['display_order'] as num? ?? 1000)
            .compareTo(b['display_order'] as num? ?? 1000);
        return byOrder != 0 ? byOrder : _s(a['brand_code']).compareTo(_s(b['brand_code']));
      });
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
              Text('\${children.length} براند',
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
    final visibleGroups = _groupNames.where((group) => _rowsInGroup(group).isNotEmpty).toList();
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
                ErpQuickTaskButton(label:'تحديث', icon:Icons.refresh_rounded, kind:ErpQuickTaskKind.update, onPressed:_loading || _saving ? null : _load),
                ErpQuickTaskButton(label:'عرض شجرة', icon:Icons.account_tree_outlined, kind:ErpQuickTaskKind.treeView, onPressed:() => setState(() => _viewMode = 'tree')),
                ErpQuickTaskButton(label:'عرض جدول', icon:Icons.table_rows_outlined, kind:ErpQuickTaskKind.tableView, onPressed:() => setState(() => _viewMode = 'grid')),
                ErpQuickTaskButton(label:'إضافة جديد', icon:Icons.add_circle_outline, kind:ErpQuickTaskKind.add, onPressed:_saving ? null : () => _edit()),
                ErpQuickTaskButton(label:'تعديل', icon:Icons.edit_outlined, kind:ErpQuickTaskKind.edit, onPressed:_saving || selected == null || selected['is_system'] == true ? null : () => _edit(row:selected)),
                ErpQuickTaskButton(label:'شعار البراند', icon:Icons.image_outlined, kind:ErpQuickTaskKind.image, onPressed:_saving || selected == null ? null : () => _uploadLogo(selected)),
                ErpQuickTaskButton(label:'حذف', icon:Icons.delete_outline, kind:ErpQuickTaskKind.delete, onPressed:_saving || selected == null || selected['is_system'] == true ? null : _delete),
              ]),
            ),
          ),
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
              Expanded(child:Text('عدد البراندات/الماركات: \${rows.length}',
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
                                DataCell(Text(_s(row['brand_group']).isEmpty ? '—' : _s(row['brand_group']))),
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
      ),
    );
  }
}
