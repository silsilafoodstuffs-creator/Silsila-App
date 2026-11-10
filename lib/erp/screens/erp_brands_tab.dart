import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/erp_quick_task_button.dart';
import '../widgets/erp_center_toast.dart';

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
        .select('id,brand_code,brand_name,brand_name_en,is_active,is_system')
        .eq('company_id', widget.companyId.trim())
        .order('brand_code');
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String,dynamic>>.from(rows);
        if (!_rows.any((row) => _s(row['id']) == _selectedId)) {
          _selectedId = _rows.isEmpty ? null : _s(_rows.first['id']);
        }
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
      _s(row['brand_name_en']).toLowerCase().contains(term)
    ).toList();
  }

  Future<void> _edit({Map<String,dynamic>? row}) async {
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
          .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim());
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

  Future<void> _toggle(Map<String,dynamic> row) async {
    if (row['is_system'] == true) return;
    try {
      await _db.from('erp_brands').update({'is_active':row['is_active'] != true})
        .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim());
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
    await _db.from('erp_brands').delete()
      .eq('id',_s(row['id'])).eq('company_id',widget.companyId.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    final selected = _selectedRow();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: const Color(0xFFF5EFFB),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ErpQuickTaskButton(label:'تحديث',icon:Icons.refresh_rounded,onPressed:_loading || _saving ? null : _load),
                ErpQuickTaskButton(label:'إضافة',icon:Icons.add_circle_outline,onPressed:_saving ? null : () => _edit()),
                ErpQuickTaskButton(label:'تعديل',icon:Icons.edit_outlined,onPressed:_saving || selected == null ? null : () => _edit(row:selected)),
                ErpQuickTaskButton(label:'حذف',icon:Icons.delete_outline,onPressed:_saving || selected == null ? null : _delete),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12,8,12,5),
            child: TextField(
              controller:_search,
              onChanged:(_) => setState(() {}),
              decoration: const InputDecoration(
                labelText:'بحث بكود البراند أو اسمه',
                prefixIcon:Icon(Icons.search,color:Color(0xFF3E007D)),
                isDense:true,
                border:OutlineInputBorder(),
              ),
            ),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!,style:const TextStyle(color:Colors.red)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:12,vertical:3),
            child: Text('عدد البراندات/الماركات: ${rows.length}',style:const TextStyle(color:Color(0xFF3E007D),fontWeight:FontWeight.w800)),
          ),
          Expanded(
            child:_loading
              ? const Center(child:CircularProgressIndicator())
              : rows.isEmpty
                ? const Center(child:Text('لا توجد براندات مطابقة للبحث.'))
                : SingleChildScrollView(
                    child:SingleChildScrollView(
                      scrollDirection:Axis.horizontal,
                      child:DataTable(
                        headingRowColor:WidgetStateProperty.all(const Color(0xFFF5EFFB)),
                        columns:const [
                          DataColumn(label:Text('كود البراند')),
                          DataColumn(label:Text('اسم البراند/الماركة')),
                          DataColumn(label:Text('الاسم الإنجليزي')),
                          DataColumn(label:Text('الحالة')),
                          DataColumn(label:Text('نوع السجل')),
                        ],
                        rows:rows.map((row){
                          final id=_s(row['id']);
                          return DataRow(
                            selected:_selectedId==id,
                            onSelectChanged:(_)=>setState(()=>_selectedId=id),
                            cells:[
                              DataCell(Text(_s(row['brand_code']),style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF3E007D)))),
                              DataCell(Text(_s(row['brand_name']))),
                              DataCell(Text(_s(row['brand_name_en']))),
                              DataCell(Checkbox(
                                shape:const CircleBorder(),
                                value:row['is_active']==true,
                                onChanged:row['is_system']==true?null:(_)=>_toggle(row),
                              )),
                              DataCell(Text(row['is_system']==true?'افتراضي':'براند')),
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
